#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Cau 6 - DataFrame pipeline bang PySpark tren YARN.

Doc CSV (orders, customers, products) + JSON Lines (events) tu vung raw HDFS,
lam sach theo quy uoc chung (14.408 don), join danh muc (broadcast), doi chieu
su kien luong voi don hang, ghi vung curated (Parquet phan vung
year/month/category) va xuat ket qua tong hop:
  - category_month        : doanh thu, ty le tra theo danh muc x thang (Spark SQL)
  - product_growth        : tang truong san pham (3 thang cuoi so voi 3 thang truoc + do doc)
  - customer_churn        : RFM + muc nguy co roi bo cua 1.200 khach hang
  - reconcile_events      : doi chieu 5.000 su kien JSON voi don hang

Chay (trong may1, thu muc ~/src):
  spark-submit cau06_spark/pipeline.py
  spark-submit cau06_spark/pipeline.py --out /tmp/x --curated /tmp/x/curated --local-out /tmp/x_local
"""
import argparse
import csv
import json
import os
import sys
import time
import urllib.request
from decimal import Decimal, ROUND_HALF_UP
from functools import reduce

from pyspark import StorageLevel
from pyspark.sql import DataFrame, SparkSession, Window
from pyspark.sql import functions as F

SNAPSHOT = "2026-08-01"            # ban chup chuan (quy uoc muc 1)
REF_DATE = "2026-07-31"            # ngay cuoi cung co don hang
FIRST_MONTH = (2025, 1)            # month_idx = 0 ung voi 2025-01
WINDOW_MONTHS = 3                  # cua so so sanh tang truong: 3 thang
MIN_ORDERS = 3                     # nguong so don toi thieu moi cua so
GROWTH_PCT = 50.0                  # tang >= 50% doanh thu -> "tang truong nhanh"
CHURN_DAYS = 90                    # khong mua trong 90 ngay -> nghi roi bo
BAD_FLAGS = ["OUTLIER", "DUPLICATE", "LATE"]

ORDERS_DDL = (
    "record_id STRING, timestamp STRING, province STRING, source_system STRING, "
    "ingest_mode STRING, data_format STRING, order_id STRING, customer_id STRING, "
    "product_id STRING, category STRING, customer_segment STRING, sales_channel STRING, "
    "quantity INT, unit_price DOUBLE, discount_rate DOUBLE, shipping_fee DOUBLE, "
    "net_revenue DOUBLE, payment_method STRING, delivery_days DOUBLE, returned_flag INT, "
    "review_score INT, campaign_id STRING, quality_flag STRING")
CUSTOMERS_DDL = (
    "customer_id STRING, customer_segment STRING, age_group STRING, gender STRING, "
    "province STRING, join_date DATE, loyalty_score INT, preferred_channel STRING")
PRODUCTS_DDL = (
    "product_id STRING, category STRING, brand STRING, unit_cost DOUBLE, list_price DOUBLE, "
    "supplier_id STRING, rating DOUBLE, active_flag INT")
EVENTS_DDL = (
    "event_id STRING, event_time STRING, event_type STRING, source STRING, "
    "payload STRUCT<category: STRING, customer_segment: STRING, "
    "net_revenue: DOUBLE, returned_flag: INT>")
TS_FMT = "yyyy-MM-dd'T'HH:mm:ss"


# --------------------------------------------------------------------------- log
class Log:
    """In ra man hinh dong thoi giu lai de ghi output/pipeline_log.txt."""

    def __init__(self):
        self.lines = []

    def __call__(self, *parts):
        s = " ".join(str(p) for p in parts)
        print(s, flush=True)
        self.lines.extend(s.split("\n"))

    def show(self, df, n=20, title=None, truncate=0):
        if title:
            self("--- " + title)
        # showString: chuoi giong df.show() de ghi duoc vao log
        self(df._jdf.showString(n, truncate, False).rstrip())

    def explain(self, df, title):
        self("--- explain(formatted): " + title)
        jvm = df.sql_ctx._sc._jvm
        self(jvm.PythonSQLUtils.explainString(df._jdf.queryExecution(), "formatted").rstrip())


# --------------------------------------------------------------------------- doc
def strip_bom(df):
    """Phong ho: neu ten cot dau con BOM (doc bang header + inferSchema) thi bo di."""
    bom = chr(0xFEFF)
    return df.toDF(*[c.lstrip(bom) for c in df.columns])


def raw_path(table, fname, snapshot):
    return "/btl/raw/%s/ingest_date=%s/%s" % (table, snapshot, fname)


def read_sources(spark, snapshot, scale=1):
    """Doc 3 CSV + 1 JSON tu vung raw. scale > 1: hop (union) nhieu ban orders de thu quy mo."""
    def read_csv(table, fname, ddl):
        return strip_bom(spark.read.csv(raw_path(table, fname, snapshot), schema=ddl,
                                        header=True, mode="FAILFAST"))
    orders = read_csv("orders", "orders.csv", ORDERS_DDL)
    if scale > 1:
        copies = [read_csv("orders", "orders.csv", ORDERS_DDL) for _ in range(scale - 1)]
        orders = reduce(DataFrame.union, [orders] + copies)
    customers = read_csv("customers", "customers.csv", CUSTOMERS_DDL)
    products = read_csv("products", "products.csv", PRODUCTS_DDL)
    events = spark.read.schema(EVENTS_DDL).json(raw_path("events", "events_stream.jsonl", snapshot))
    return orders, customers, products, events


# --------------------------------------------------------------------------- lam sach
def clean_orders(orders):
    """Quy uoc muc 2: bo OUTLIER/DUPLICATE/LATE, giu MISSING; o trong -> NULL; them cot dan xuat."""
    y0, m0 = FIRST_MONTH
    blank_to_null = lambda c: F.when(F.trim(F.col(c)) == "", F.lit(None)).otherwise(F.trim(F.col(c)))
    return (orders
            .withColumn("quality_flag", F.upper(F.trim("quality_flag")))
            .filter(~F.col("quality_flag").isin(BAD_FLAGS))                      # T1 filter
            .withColumn("campaign_id", blank_to_null("campaign_id"))             # '' -> NULL
            .withColumn("order_ts", F.to_timestamp("timestamp", TS_FMT))         # T2 chuoi -> TIMESTAMP
            .withColumn("delivery_days", F.col("delivery_days").cast("int"))     # sau loc deu nguyen
            .withColumn("order_date", F.to_date("order_ts"))
            .withColumn("year", F.year("order_ts"))
            .withColumn("month", F.lpad(F.month("order_ts").cast("string"), 2, "0"))
            .withColumn("ym", F.date_format("order_ts", "yyyy-MM"))
            .withColumn("month_idx", (F.year("order_ts") - y0) * 12 + F.month("order_ts") - m0)
            .withColumn("hour", F.hour("order_ts"))
            .withColumn("gross_amount", F.round(F.col("quantity") * F.col("unit_price"), 2))
            .withColumn("discount_amount",
                        F.round(F.col("quantity") * F.col("unit_price") * F.col("discount_rate"), 2))
            .withColumn("has_review", F.col("review_score").isNotNull())
            .withColumn("has_campaign", F.col("campaign_id").isNotNull())
            .drop("timestamp", "record_id"))                                     # record_id == order_id


def enrich(clean, customers, products, events):
    """Join 2 danh muc (broadcast, bang nho) + gan co don da xuat hien trong luong su kien."""
    prod = products.select("product_id", "brand", "supplier_id",
                           F.col("rating").alias("product_rating"),
                           F.col("active_flag").alias("product_active"))
    cust = customers.select("customer_id", F.col("province").alias("home_province"),
                            "age_group", "gender", "join_date", "loyalty_score",
                            "preferred_channel")
    seen = events.select(F.regexp_replace("event_id", "^EVT-", "").alias("order_id")) \
                 .distinct().withColumn("seen_in_stream", F.lit(True))
    return (clean
            .join(F.broadcast(prod), "product_id", "left")                       # T3 join
            .join(F.broadcast(cust), "customer_id", "left")
            .join(F.broadcast(seen), "order_id", "left")
            .fillna(False, subset=["seen_in_stream"])
            .withColumn("ship_to_home", F.col("province") == F.col("home_province"))
            .withColumn("tenure_days", F.datediff("order_date", "join_date")))


# --------------------------------------------------------------------------- phan tich
def category_month_sql(spark, view):
    """Spark SQL: bang doi chieu Pig-MR-Spark (quy uoc muc 3). Tien cong bang DECIMAL -> chinh xac."""
    return spark.sql("""
        SELECT category,
               ym                                                  AS month,
               COUNT(*)                                            AS orders,
               CAST(SUM(CAST(net_revenue AS DECIMAL(14,2))) AS DECIMAL(16,2)) AS net_revenue,
               SUM(returned_flag)                                  AS returned,
               ROUND(100.0 * SUM(returned_flag) / COUNT(*), 2)     AS return_rate_pct
        FROM {v}
        GROUP BY category, ym
        ORDER BY category, month
    """.format(v=view))


def product_growth(spark, enriched, products, last_idx):
    """Tang truong theo san pham: R = 3 thang cuoi, P = 3 thang lien truoc, do doc chuoi 19 thang."""
    r_lo, p_lo = last_idx - WINDOW_MONTHS + 1, last_idx - 2 * WINDOW_MONTHS + 1
    monthly = (enriched.groupBy("product_id", "month_idx")                       # T4 groupBy
               .agg(F.sum("net_revenue").alias("rev"), F.sum("quantity").alias("qty"),
                    F.count("*").alias("n")))
    # lap day luoi san pham x thang (thang khong ban = 0) de tinh do doc dung
    months = spark.range(0, last_idx + 1).withColumnRenamed("id", "month_idx") \
                  .withColumn("month_idx", F.col("month_idx").cast("int"))
    grid = products.select("product_id", "category", "brand").crossJoin(months)  # T5 crossJoin
    series = grid.join(monthly, ["product_id", "month_idx"], "left").fillna(0, ["rev", "qty", "n"])
    in_r = F.col("month_idx").between(r_lo, last_idx)
    in_p = F.col("month_idx").between(p_lo, r_lo - 1)
    g = (series.groupBy("product_id", "category", "brand")
         .agg(F.round(F.sum(F.when(in_r, F.col("rev")).otherwise(0)), 2).alias("rev_recent"),
              F.round(F.sum(F.when(in_p, F.col("rev")).otherwise(0)), 2).alias("rev_prev"),
              F.sum(F.when(in_r, F.col("qty")).otherwise(0)).alias("qty_recent"),
              F.sum(F.when(in_p, F.col("qty")).otherwise(0)).alias("qty_prev"),
              F.sum(F.when(in_r, F.col("n")).otherwise(0)).alias("orders_recent"),
              F.sum(F.when(in_p, F.col("n")).otherwise(0)).alias("orders_prev"),
              F.sum("n").alias("orders_total"),
              F.avg("rev").alias("avg_month_rev"),
              (F.covar_pop("month_idx", "rev") / F.var_pop("month_idx")).alias("slope")))
    g = (g.withColumn("growth_rev_pct",
                      F.when(F.col("rev_prev") > 0,
                             F.round((F.col("rev_recent") - F.col("rev_prev")) / F.col("rev_prev") * 100, 2)))
          .withColumn("growth_qty_pct",
                      F.when(F.col("qty_prev") > 0,
                             F.round((F.col("qty_recent") - F.col("qty_prev")) / F.col("qty_prev") * 100, 2)))
          # z xap xi cho hieu 2 bien Poisson: (R - P) / sqrt(R + P); |z| >= 1.96 ~ khac biet co y nghia
          .withColumn("z_orders",
                      F.round((F.col("orders_recent") - F.col("orders_prev"))
                              / F.sqrt(F.greatest(F.col("orders_recent") + F.col("orders_prev"), F.lit(1))), 2))
          .withColumn("slope_pct_month", F.round(F.col("slope") / F.col("avg_month_rev") * 100, 2))
          .withColumn("eligible", (F.col("orders_prev") >= MIN_ORDERS) & (F.col("orders_recent") >= MIN_ORDERS))
          # tang nhanh: du nguong, doanh thu VA so luong cung tang >= 50%, xu huong 19 thang di len
          .withColumn("fast_growing", F.col("eligible") & (F.col("growth_rev_pct") >= GROWTH_PCT)
                      & (F.col("growth_qty_pct") >= GROWTH_PCT) & (F.col("slope") > 0))
          .withColumn("significant", F.col("z_orders") >= 1.96)
          .withColumn("rank_in_category",                                      # T6 window
                      F.when(F.col("eligible"),
                             F.row_number().over(Window.partitionBy("category", "eligible")
                                                 .orderBy(F.desc_nulls_last("growth_rev_pct"), "product_id"))))
          .drop("slope", "avg_month_rev"))
    return g


def customer_churn(enriched, customers, last_idx):
    """Nguy co roi bo: recency den 31/07/2026, so don 6 thang cuoi so voi 6 thang truoc, RFM."""
    l6, p6 = last_idx - 5, last_idx - 11
    agg = (enriched.groupBy("customer_id")
           .agg(F.max("order_date").alias("last_order"), F.min("order_date").alias("first_order"),
                F.count("*").alias("frequency"),
                F.round(F.sum("net_revenue"), 2).alias("monetary"),
                F.sum("returned_flag").alias("returned"),
                F.round(F.avg("review_score"), 2).alias("avg_review"),
                F.sum("delivery_days").alias("delivery_days_sum"),
                F.sum(F.when(F.col("review_score").isNotNull(), 1).otherwise(0)).alias("reviews"),
                F.sum("review_score").alias("review_sum"),
                F.sum(F.when(F.col("month_idx") >= l6, 1).otherwise(0)).alias("orders_last6m"),
                F.sum(F.when(F.col("month_idx").between(p6, l6 - 1), 1).otherwise(0)).alias("orders_prev6m")))
    c = (customers.select("customer_id", "customer_segment", "loyalty_score", "preferred_channel")
         .join(agg, "customer_id", "left")
         .fillna(0, ["frequency", "monetary", "returned", "orders_last6m", "orders_prev6m"])
         .withColumn("recency_days", F.datediff(F.lit(REF_DATE), F.col("last_order")))
         .withColumn("avg_gap_days",
                     F.when(F.col("frequency") > 1,
                            F.round(F.datediff("last_order", "first_order") / (F.col("frequency") - 1), 1))))
    # RFM: chia 5 nhom (5 = tot nhat); recency nho = tot
    c = (c.withColumn("r_score", F.ntile(5).over(Window.orderBy(F.desc("recency_days"), "customer_id")))
          .withColumn("f_score", F.ntile(5).over(Window.orderBy("frequency", "customer_id")))
          .withColumn("m_score", F.ntile(5).over(Window.orderBy("monetary", "customer_id")))
          .withColumn("rfm", F.concat_ws("", "r_score", "f_score", "m_score")))
    lapsed = (F.col("recency_days") > CHURN_DAYS) | F.col("last_order").isNull()
    overdue = F.col("recency_days") > F.greatest(F.lit(60.0), 2 * F.col("avg_gap_days"))
    decline = (F.col("orders_prev6m") >= 4) & (F.col("orders_last6m") * 2 <= F.col("orders_prev6m"))
    c = c.withColumn("churn_risk",
                     F.when(lapsed & (F.col("orders_last6m") < F.col("orders_prev6m")), "HIGH")
                      .when(lapsed | overdue | decline, "MEDIUM")
                      .otherwise("LOW"))
    return c


def reconcile_events(orders_raw, events):
    """Doi chieu luong (JSON) voi lo (CSV): khop ma don, lech gia tri, nhan chat luong cua don goc."""
    ev = (events.withColumn("order_id", F.regexp_replace("event_id", "^EVT-", ""))
                .select("order_id", "event_time", "source", F.col("payload.*")))
    o = orders_raw.select("order_id", F.col("timestamp").alias("o_time"),
                          F.col("source_system").alias("o_source"),
                          F.col("category").alias("o_category"),
                          F.col("customer_segment").alias("o_segment"),
                          F.col("net_revenue").alias("o_rev"),
                          F.col("returned_flag").alias("o_ret"),
                          F.upper(F.trim("quality_flag")).alias("quality_flag"))
    j = ev.join(o, "order_id", "left")
    mism = lambda a, b: F.sum(F.when(~F.col(a).eqNullSafe(F.col(b)), 1).otherwise(0))
    is_clean = ~F.col("quality_flag").isin(BAD_FLAGS)
    summary = j.agg(
        F.count("*").alias("events"),
        F.sum(F.when(F.col("o_rev").isNotNull(), 1).otherwise(0)).alias("matched_orders"),
        mism("event_time", "o_time").alias("diff_time"),
        mism("source", "o_source").alias("diff_source"),
        mism("category", "o_category").alias("diff_category"),
        mism("customer_segment", "o_segment").alias("diff_segment"),
        mism("net_revenue", "o_rev").alias("diff_net_revenue"),
        mism("returned_flag", "o_ret").alias("diff_returned"),
        F.sum(F.when(is_clean, 1).otherwise(0)).alias("events_of_clean_orders"),
        F.round(F.sum("net_revenue"), 2).alias("event_revenue"),
        F.round(F.sum(F.when(is_clean, F.col("net_revenue"))), 2).alias("event_revenue_clean"))
    by_flag = j.groupBy("quality_flag").agg(F.count("*").alias("events")).orderBy("quality_flag")
    return summary, by_flag


# --------------------------------------------------------------------------- tien ich
def fmt(v):
    """Dinh dang so cho CSV: Decimal giu nguyen, float lam tron 2 chu so, None -> rong."""
    if v is None:
        return ""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, Decimal):
        return str(v)
    if isinstance(v, float):
        return str(Decimal(repr(v)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP))
    return str(v)


def write_local_csv(path, header, rows):
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(header)
        for r in rows:
            w.writerow([fmt(r[c]) for c in header])


class Metrics:
    """Lay chi so I/O (input, shuffle, output) cua cac job qua REST API cua Spark UI."""

    def __init__(self, spark):
        self.sc = spark.sparkContext
        self.base = "%s/api/v1/applications/%s" % (self.sc.uiWebUrl, self.sc.applicationId)

    def _get(self, path):
        with urllib.request.urlopen(self.base + path, timeout=10) as r:
            return json.loads(r.read().decode("utf-8"))

    def group(self, group_id):
        keys = ["inputBytes", "inputRecords", "shuffleReadBytes", "shuffleWriteBytes",
                "outputBytes", "memoryBytesSpilled", "diskBytesSpilled", "numTasks"]
        out = dict.fromkeys(keys, 0)
        out.update(jobs=0, stages=0)
        try:
            time.sleep(1.0)  # cho listener cap nhat xong
            for job in self._get("/jobs"):
                if job.get("jobGroup") != group_id:
                    continue
                out["jobs"] += 1
                for sid in job.get("stageIds", []):
                    for st in self._get("/stages/%d" % sid):
                        if st.get("status") != "COMPLETE":
                            continue
                        out["stages"] += 1
                        for k in keys:
                            out[k] += st.get(k, 0)
        except Exception as e:  # REST khong co -> van chay tiep, chi thieu so lieu I/O
            out["error"] = str(e)
        return out


# --------------------------------------------------------------------------- pipeline
def run(spark, snapshot=SNAPSHOT, scale=1, cache=True, log=None):
    """Phan loi dung chung cho pipeline va bench: tra ve dict ket qua (da collect) + dataframe."""
    log = log or Log()
    t = {}
    t0 = time.time()
    orders, customers, products, events = read_sources(spark, snapshot, scale)
    clean = clean_orders(orders)
    enriched = enrich(clean, customers, products, events)
    if cache:
        enriched.persist(StorageLevel.MEMORY_AND_DISK)   # dung lai cho >= 5 action phia sau
    res = {"enriched": enriched, "orders_raw": orders, "customers": customers,
           "products": products, "events": events}

    # A1 count: so ban ghi sau lam sach (va vat chat hoa cache)
    res["n_clean"] = enriched.count()
    t["clean_join_count"] = time.time() - t0

    # A2 first: thang cuoi cung co du lieu + tong kiem tra
    t1 = time.time()
    tot = enriched.agg(F.max("month_idx").alias("last_idx"),
                       F.sum(F.col("net_revenue").cast("decimal(14,2)")).alias("revenue"),
                       F.sum("returned_flag").alias("returned"),
                       F.sum(F.when(F.col("seen_in_stream"), 1).otherwise(0)).alias("seen_in_stream"),
                       F.sum(F.when(F.col("home_province").isNull() | F.col("brand").isNull(), 1)
                             .otherwise(0)).alias("unmatched_join")).first()
    res["totals"] = tot.asDict()
    last_idx = tot["last_idx"]

    # A3 collect: Spark SQL danh muc x thang
    enriched.createOrReplaceTempView("orders_clean")
    cm = category_month_sql(spark, "orders_clean")
    res["category_month_df"] = cm
    res["category_month"] = cm.collect()

    # A4 collect: tang truong san pham
    pg = product_growth(spark, enriched, products, last_idx)
    res["product_growth_df"] = pg
    res["product_growth"] = pg.orderBy(F.desc_nulls_last("growth_rev_pct"), "product_id").collect()

    # A5 collect: nguy co roi bo
    ch = customer_churn(enriched, customers, last_idx)
    res["churn_df"] = ch
    res["churn"] = ch.orderBy("customer_id").collect()
    # duong co so: neu KHONG ai roi bo (Poisson toc do khong doi), ky vong bao nhieu khach
    # khong mua trong CHURN_DAYS ngay cuoi? (577 ngay = 01/01/2025..31/07/2026)
    days = F.datediff(F.lit(REF_DATE), F.lit("2025-01-01")) + 1
    res["churn_baseline"] = ch.agg(
        F.round(F.sum(F.exp(-F.col("frequency") / days * CHURN_DAYS)), 1).alias("expected_lapsed"),
        F.sum(F.when(F.col("recency_days") > CHURN_DAYS, 1).otherwise(0)).alias("observed_lapsed")).first().asDict()

    # A6 collect: doi chieu su kien luong
    summary, by_flag = reconcile_events(orders, events)
    res["reconcile"] = summary.first().asDict()
    res["reconcile_by_flag"] = by_flag.collect()
    t["analytics"] = time.time() - t1
    t["total"] = time.time() - t0
    res["timings"] = t
    return res


def growth_rows(res):
    return [r for r in res["product_growth"] if r["fast_growing"]]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    here = os.path.dirname(os.path.abspath(__file__))
    ap.add_argument("--snapshot", default=SNAPSHOT)
    ap.add_argument("--out", default="/btl/output/cau06_spark")
    ap.add_argument("--curated", default="/btl/curated/orders")
    ap.add_argument("--local-out", default=os.path.join(here, "output"))
    ap.add_argument("--no-cache", action="store_true")
    args = ap.parse_args()

    spark = SparkSession.builder.appName("cau06-spark-pipeline").getOrCreate()
    spark.sparkContext.setLogLevel("WARN")
    os.makedirs(args.local_out, exist_ok=True)
    log = Log()
    metrics = Metrics(spark)
    wall0 = time.time()
    log("== Cau 6 - Spark %s, app %s, shuffle.partitions=%s" % (
        spark.version, spark.sparkContext.applicationId, spark.conf.get("spark.sql.shuffle.partitions")))

    spark.sparkContext.setJobGroup("analytics", "doc + lam sach + join + phan tich")
    res = run(spark, args.snapshot, 1, not args.no_cache, log)
    enriched, tim = res["enriched"], res["timings"]
    spark.sparkContext.setJobGroup("report", "in vi du, schema, explain ra log")

    # ---- ghi ket qua ra log
    raw_n = res["orders_raw"].count()                                             # A7 count
    log("\n== 1. Doc va lam sach")
    log("orders raw: %d | sau lam sach: %d | bo: %d" % (raw_n, res["n_clean"], raw_n - res["n_clean"]))
    log("tong kiem tra:", json.dumps({k: str(v) for k, v in res["totals"].items()}))
    log.show(res["orders_raw"].groupBy("quality_flag").count().orderBy("quality_flag"),
             title="quality_flag truoc lam sach")
    log.show(res["orders_raw"].filter(F.col("order_id").isin("ORD0000002", "ORD0000014"))
             .select("order_id", "timestamp", "quantity", "unit_price", "delivery_days",
                     "review_score", "campaign_id", "quality_flag"),
             title="vi du TRUOC (raw, chuoi/double)")
    log.show(enriched.filter(F.col("order_id").isin("ORD0000002", "ORD0000014"))
             .select("order_id", "order_ts", "ym", "month_idx", "delivery_days", "review_score",
                     "has_review", "campaign_id", "brand", "home_province", "seen_in_stream"),
             title="vi du SAU (curated)")
    log("--- schema curated")
    log(enriched._jdf.schema().treeString().rstrip())
    log.explain(enriched, "enriched (clean + broadcast join)")

    log("\n== 2. Danh muc x thang (Spark SQL) - %d dong" % len(res["category_month"]))
    log.show(res["category_month_df"], n=8)

    pg = res["product_growth"]
    fg = growth_rows(res)
    eligible = [r for r in pg if r["eligible"]]
    log("\n== 3. Tang truong san pham (R = 3 thang cuoi, P = 3 thang truoc)")
    log("san pham du nguong (>= %d don moi cua so): %d/%d; tang truong nhanh: %d" % (
        MIN_ORDERS, len(eligible), len(pg), len(fg)))
    log("z_orders >= 1.96: %d; <= -1.96: %d (ngau nhien ky vong ~2,5%% moi phia)" % (
        sum(1 for r in pg if r["z_orders"] >= 1.96), sum(1 for r in pg if r["z_orders"] <= -1.96)))
    log.show(res["product_growth_df"].filter("fast_growing")
             .orderBy(F.desc("growth_rev_pct"), "product_id"), n=15)

    ch = res["churn"]
    log("\n== 4. Nguy co roi bo (moc %s)" % REF_DATE)
    for lvl in ("HIGH", "MEDIUM", "LOW"):
        log("%-6s %d" % (lvl, sum(1 for r in ch if r["churn_risk"] == lvl)))
    log("duong co so Poisson:", res["churn_baseline"])
    churn_df = res["churn_df"]
    log.show(churn_df.groupBy("customer_segment").pivot("churn_risk", ["HIGH", "MEDIUM", "LOW"])
             .count().orderBy("customer_segment"), title="churn_risk x segment")
    log.show(churn_df.filter(F.col("churn_risk") == "HIGH").orderBy(F.desc("recency_days"), "customer_id")
             .select("customer_id", "customer_segment", "last_order", "recency_days", "frequency",
                     "monetary", "orders_prev6m", "orders_last6m", "rfm"), n=10, title="HIGH (10 dau)")

    log("\n== 5. Doi chieu su kien JSON voi don hang")
    log(json.dumps({k: str(v) for k, v in res["reconcile"].items()}, ensure_ascii=False))
    for r in res["reconcile_by_flag"]:
        log("  quality_flag %-9s %d su kien" % (r["quality_flag"], r["events"]))

    # ---- ghi HDFS
    spark.sparkContext.setJobGroup("write", "ghi curated + output")
    t2 = time.time()
    (enriched.repartition("year", "month", "category")                         # T7 repartition
     .write.mode("overwrite").partitionBy("year", "month", "category")
     .parquet(args.curated))                                                   # A8 write
    t_cur = time.time() - t2
    out = args.out.rstrip("/")
    res["category_month_df"].coalesce(1).write.mode("overwrite") \
        .option("header", True).csv(out + "/category_month")
    res["product_growth_df"].write.mode("overwrite").parquet(out + "/product_growth")
    res["product_growth_df"].filter("fast_growing").orderBy(F.desc("growth_rev_pct"), "product_id") \
        .coalesce(1).write.mode("overwrite").option("header", True).csv(out + "/fast_growing_products")
    churn_df.write.mode("overwrite").parquet(out + "/customer_churn")
    churn_df.filter(F.col("churn_risk") != "LOW").orderBy("churn_risk", F.desc("recency_days"), "customer_id") \
        .coalesce(1).write.mode("overwrite").option("header", True).csv(out + "/churn_risk_customers")
    t_out = time.time() - t2 - t_cur

    # A9 count: doc lai curated de kiem tra
    cur_back = spark.read.parquet(args.curated)
    n_back = cur_back.count()
    n_parts = cur_back.select("year", "month", "category").distinct().count()
    as_int = lambda c: F.sum(F.col(c).cast("int"))
    dstat = cur_back.agg(as_int("has_review").alias("has_review"), as_int("has_campaign").alias("has_campaign"),
                         as_int("seen_in_stream").alias("seen_in_stream"), as_int("ship_to_home").alias("ship_to_home"),
                         F.sum(F.when(F.col("product_active") == 0, 1).otherwise(0)).alias("product_inactive"),
                         F.sum(F.when(F.col("quality_flag") == "MISSING", 1).otherwise(0)).alias("quality_missing"),
                         F.min("delivery_days").alias("delivery_min"), F.max("delivery_days").alias("delivery_max"),
                         F.min("tenure_days").alias("tenure_min"), F.max("tenure_days").alias("tenure_max"),
                         F.round(F.avg("tenure_days"), 1).alias("tenure_avg")).first().asDict()
    jvm = spark.sparkContext._jvm
    cpath = jvm.org.apache.hadoop.fs.Path(args.curated)
    cs = cpath.getFileSystem(spark.sparkContext._jsc.hadoopConfiguration()).getContentSummary(cpath)
    log("\n== 6. Ghi HDFS")
    log("curated %s: %d dong, %d phan vung year/month/category (%.1fs)" % (args.curated, n_back, n_parts, t_cur))
    log("curated tren HDFS: %d byte (1 ban sao), %d tep, %d cot" % (cs.getLength(), cs.getFileCount(),
                                                                   len(cur_back.columns)))
    log("cot dan xuat (doc lai tu curated):", json.dumps(dstat))
    log("output  %s: category_month, product_growth, fast_growing_products, customer_churn, "
        "churn_risk_customers (%.1fs)" % (out, t_out))
    enriched.unpersist()

    # ---- ghi ban sao nho vao output/ (local)
    lo = args.local_out
    write_local_csv(os.path.join(lo, "compare_category_month.csv"),
                    ["category", "month", "orders", "net_revenue", "returned", "return_rate_pct"],
                    res["category_month"])
    gcols = ["product_id", "category", "brand", "orders_prev", "orders_recent", "qty_prev", "qty_recent",
             "rev_prev", "rev_recent", "growth_rev_pct", "growth_qty_pct", "z_orders", "significant", "slope_pct_month",
             "rank_in_category"]
    write_local_csv(os.path.join(lo, "fast_growing_products.csv"), gcols, fg)
    ccols = ["customer_id", "customer_segment", "churn_risk", "last_order", "recency_days", "frequency",
             "monetary", "orders_prev6m", "orders_last6m", "avg_gap_days", "returned", "avg_review", "rfm"]
    order = {"HIGH": 0, "MEDIUM": 1, "LOW": 2}
    risky = sorted([r for r in ch if r["churn_risk"] != "LOW"],
                   key=lambda r: (order[r["churn_risk"]], -(r["recency_days"] or 0), r["customer_id"]))
    write_local_csv(os.path.join(lo, "churn_risk_customers.csv"), ccols, risky)
    # tom tat churn theo segment x muc
    segs = sorted({r["customer_segment"] for r in ch})
    summ = []
    for s in segs + ["ALL"]:
        rows = [r for r in ch if s == "ALL" or r["customer_segment"] == s]
        d = {"customer_segment": s, "customers": len(rows)}
        for lvl in ("HIGH", "MEDIUM", "LOW"):
            d[lvl.lower()] = sum(1 for r in rows if r["churn_risk"] == lvl)
        d["high_pct"] = 100.0 * d["high"] / len(rows)
        d["avg_recency_days"] = sum(r["recency_days"] for r in rows) / len(rows)
        summ.append(d)
    write_local_csv(os.path.join(lo, "churn_summary.csv"),
                    ["customer_segment", "customers", "high", "medium", "low", "high_pct", "avg_recency_days"],
                    summ)
    # tom tat tang truong theo danh muc (tong 3 thang cuoi vs 3 thang truoc)
    cats = sorted({r["category"] for r in pg})
    crow = []
    for c in cats:
        rows = [r for r in pg if r["category"] == c]
        rp, rr = sum(r["rev_prev"] for r in rows), sum(r["rev_recent"] for r in rows)
        crow.append({"category": c, "products": len(rows),
                     "eligible": sum(1 for r in rows if r["eligible"]),
                     "fast_growing": sum(1 for r in rows if r["fast_growing"]),
                     "rev_prev": rp, "rev_recent": rr, "growth_rev_pct": (rr - rp) / rp * 100})
    write_local_csv(os.path.join(lo, "growth_by_category.csv"),
                    ["category", "products", "eligible", "fast_growing", "rev_prev", "rev_recent",
                     "growth_rev_pct"], crow)
    # tom tat tang truong: so voi muc ngau nhien + ty trong doanh thu cua nhom tang nhanh
    gsum = [("products", len(pg)), ("eligible", len(eligible)), ("fast_growing", len(fg)),
            ("z_ge_1.96", sum(1 for r in pg if r["z_orders"] >= 1.96)),
            ("z_le_-1.96", sum(1 for r in pg if r["z_orders"] <= -1.96)),
            ("expected_by_chance_each_side", 0.025 * len(pg)),
            ("fast_growing_and_significant", sum(1 for r in fg if r["significant"])),
            ("rev_recent_all", sum(r["rev_recent"] for r in pg)), ("rev_prev_all", sum(r["rev_prev"] for r in pg)),
            ("rev_recent_fast", sum(r["rev_recent"] for r in fg)), ("rev_prev_fast", sum(r["rev_prev"] for r in fg))]
    with open(os.path.join(lo, "growth_summary.csv"), "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["metric", "value"])
        for k, v in gsum:
            w.writerow([k, fmt(v)])
    # rui ro roi bo x ba muc tieu (doanh thu, hoan tra, giao hang): khach HIGH co khac khach LOW?
    rrows = []
    for lvl in ("HIGH", "MEDIUM", "LOW"):
        rows = [r for r in ch if r["churn_risk"] == lvl]
        n_ord = sum(r["frequency"] for r in rows)
        rrows.append({"churn_risk": lvl, "customers": len(rows), "orders": n_ord,
                      "avg_frequency": n_ord / len(rows),
                      "avg_monetary": sum(r["monetary"] for r in rows) / len(rows),
                      "return_rate_pct": 100.0 * sum(r["returned"] for r in rows) / n_ord,
                      "avg_review": sum(r["review_sum"] or 0 for r in rows) / sum(r["reviews"] for r in rows),
                      "avg_delivery_days": sum(r["delivery_days_sum"] or 0 for r in rows) / n_ord,
                      "avg_recency_days": sum(r["recency_days"] for r in rows) / len(rows)})
    write_local_csv(os.path.join(lo, "churn_by_risk.csv"),
                    ["churn_risk", "customers", "orders", "avg_frequency", "avg_monetary", "return_rate_pct",
                     "avg_review", "avg_delivery_days", "avg_recency_days"], rrows)
    rec = dict(res["reconcile"])
    for r in res["reconcile_by_flag"]:
        rec["events_flag_" + r["quality_flag"]] = r["events"]
    with open(os.path.join(lo, "reconcile_events.csv"), "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["metric", "value"])
        for k, v in rec.items():
            w.writerow([k, fmt(v)])

    m = metrics.group("analytics")
    wall = time.time() - wall0
    log("\n== 7. Thoi gian (giay) va I/O cua nhom job 'analytics'")
    log("doc+lam sach+join+count: %.1f | phan tich: %.1f | ghi curated: %.1f | ghi output: %.1f | "
        "tong (trong app): %.1f" % (tim["clean_join_count"], tim["analytics"], t_cur, t_out, wall))
    log(json.dumps(m))
    ok = res["n_clean"] == n_back and res["totals"]["unmatched_join"] == 0
    log("KET QUA:", "OK" if ok else "SAI: so dong curated khac so dong sach hoac join hut")
    with open(os.path.join(lo, "pipeline_log.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(log.lines) + "\n")
    with open(os.path.join(lo, "pipeline_metrics.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"clean_join_count_s": round(tim["clean_join_count"], 2),
                   "analytics_s": round(tim["analytics"], 2), "write_curated_s": round(t_cur, 2),
                   "write_output_s": round(t_out, 2), "in_app_total_s": round(wall, 2),
                   "n_clean": res["n_clean"], "n_curated_readback": n_back, "curated_partitions": n_parts,
                   "curated_bytes": cs.getLength(), "curated_files": cs.getFileCount(), "derived": dstat,
                   "io_analytics": m}, f, indent=2)
        f.write("\n")
    spark.stop()
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
