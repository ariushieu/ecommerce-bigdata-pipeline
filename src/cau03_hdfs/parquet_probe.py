# -*- coding: utf-8 -*-
"""Cau 3 - Do thuc te ty le nen va so tep cua cac dinh dang luu tru de uoc
tinh dung luong vung staging/curated.

Doc ban chup raw (orders CSV, events JSONL), lam sach theo quy uoc chung, ghi
thu vao /tmp/cau03_probe tren HDFS theo nhieu cach roi do dung luong + so tep:
  - CSV khong nen 1 tep (gan voi staging dang van ban)
  - Parquet snappy 1 tep
  - Parquet phan vung year/month/category, 1 tep moi partition
  - Parquet phan vung year/month/category, 12 task ghi -> minh hoa tep nho
Xong thi xoa /tmp/cau03_probe. KHONG ghi vao /btl/curated (do Cau 6 ghi).

Chay (che do local de khong chiem tai nguyen YARN cua nhom):
    spark-submit --master 'local[2]' cau03_hdfs/parquet_probe.py [--out output/parquet_probe.txt]
"""
import argparse

from pyspark.sql import SparkSession
from pyspark.sql import functions as F

RAW = "/btl/raw"
SNAP = "ingest_date=2026-08-01"
PROBE = "/tmp/cau03_probe"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="output/parquet_probe.txt")
    a = ap.parse_args()

    spark = SparkSession.builder.appName("cau03-parquet-probe").getOrCreate()
    sc = spark.sparkContext
    jvm = sc._jvm
    fs = jvm.org.apache.hadoop.fs.FileSystem.get(sc._jsc.hadoopConfiguration())
    Path = jvm.org.apache.hadoop.fs.Path

    def do_luong(p):
        """(byte logic, so tep du lieu) - bo qua _SUCCESS va tep an."""
        it = fs.listFiles(Path(p), True)
        n, b = 0, 0
        while it.hasNext():
            st = it.next()
            ten = st.getPath().getName()
            if ten.startswith("_") or ten.startswith("."):
                continue
            n += 1
            b += st.getLen()
        return b, n

    fs.delete(Path(PROBE), True)

    # --- orders: doc CSV (bo BOM o ten cot), lam sach theo quy uoc chung -----
    orders = (spark.read.option("header", True).option("inferSchema", True)
              .csv("%s/orders/%s/orders.csv" % (RAW, SNAP)))
    orders = orders.toDF(*[c.lstrip(chr(0xFEFF)) for c in orders.columns])
    sach = (orders.filter(~F.col("quality_flag").isin("OUTLIER", "DUPLICATE", "LATE"))
            .withColumn("ts", F.to_timestamp("timestamp"))
            .withColumn("year", F.year("ts")).withColumn("month", F.format_string("%02d", F.month("ts")))
            .drop("ts")
            .cache())
    n_sach = sach.count()

    # ban CSV: doc moi cot dang chuoi -> ghi lai nguyen van gia tri, cung so cot
    chuoi = spark.read.option("header", True).csv("%s/orders/%s/orders.csv" % (RAW, SNAP))
    chuoi = chuoi.toDF(*[c.lstrip(chr(0xFEFF)) for c in chuoi.columns])
    (chuoi.filter(~F.col("quality_flag").isin("OUTLIER", "DUPLICATE", "LATE"))
     .coalesce(1).write.option("header", True).csv(PROBE + "/orders_csv"))
    sach.coalesce(1).write.parquet(PROBE + "/orders_parquet_1file")
    (sach.repartition("year", "month", "category").write
     .partitionBy("year", "month", "category").parquet(PROBE + "/orders_parquet_part"))
    (sach.repartition(12).write
     .partitionBy("year", "month", "category").parquet(PROBE + "/orders_parquet_part_12task"))
    n_part = sach.select("year", "month", "category").distinct().count()

    # --- events: JSON Lines -> phang hoa -> CSV / Parquet -----------------------
    ev = spark.read.json("%s/events/%s/events_stream.jsonl" % (RAW, SNAP))
    ev = ev.select("event_id", "event_time", "event_type", "source",
                   "payload.category", "payload.customer_segment",
                   "payload.net_revenue", "payload.returned_flag")
    n_ev = ev.count()
    ev.coalesce(1).write.option("header", True).csv(PROBE + "/events_csv")
    ev.coalesce(1).write.parquet(PROBE + "/events_parquet_1file")

    raw_o, _ = do_luong("%s/orders/%s" % (RAW, SNAP))
    raw_e, _ = do_luong("%s/events/%s" % (RAW, SNAP))
    dong = [
        ("orders raw CSV (15.000 dong, co BOM)", "%s/orders/%s" % (RAW, SNAP), raw_o),
        ("orders sach CSV khong nen", PROBE + "/orders_csv", raw_o),
        ("orders sach Parquet snappy 1 tep", PROBE + "/orders_parquet_1file", raw_o),
        ("orders sach Parquet year/month/category", PROBE + "/orders_parquet_part", raw_o),
        ("orders sach Parquet phan vung, 12 task", PROBE + "/orders_parquet_part_12task", raw_o),
        ("events raw JSONL", "%s/events/%s" % (RAW, SNAP), raw_e),
        ("events phang CSV khong nen", PROBE + "/events_csv", raw_e),
        ("events phang Parquet snappy 1 tep", PROBE + "/events_parquet_1file", raw_e),
    ]
    lines = ["# Cau 3 - do dung luong theo dinh dang (parquet_probe.py)",
             "# orders sau lam sach: %d dong; so partition year/month/category: %d; events: %d"
             % (n_sach, n_part, n_ev),
             "%-44s %12s %8s %12s %12s" % ("tap du lieu", "byte", "so tep", "byte/tep", "ty le/raw")]
    for ten, p, goc in dong:
        b, n = do_luong(p)
        lines.append("%-44s %12d %8d %12.0f %12.3f" % (ten, b, n, b / max(n, 1), b / goc))
    txt = "\n".join(lines) + "\n"
    print(txt)
    with open(a.out, "w", encoding="utf-8") as f:
        f.write(txt)

    fs.delete(Path(PROBE), True)
    spark.stop()


if __name__ == "__main__":
    main()
