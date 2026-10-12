#!/usr/bin/env python3
"""Cau 10 - Ban Spark cua phep tinh doi chieu (category x thang) doc tu mot duong dan bat ky.

Dung lai ham doc/lam sach cua Cau 6 (cau06_spark/pipeline.py) de logic giong het.
  spark-submit --py-files ../cau06_spark/pipeline.py spark_category_month.py <orders.csv> <out>
"""
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "cau06_spark"))

from pyspark.sql import SparkSession  # noqa: E402

import pipeline as P  # noqa: E402


def main():
    src, out = sys.argv[1], sys.argv[2]
    t0 = time.time()
    spark = SparkSession.builder.appName("cau10-category-month").getOrCreate()
    t1 = time.time()
    orders = P.strip_bom(spark.read.csv(src, schema=P.ORDERS_DDL, header=True, mode="FAILFAST"))
    P.clean_orders(orders).createOrReplaceTempView("orders_clean")
    cm = P.category_month_sql(spark, "orders_clean")
    cm.coalesce(1).write.mode("overwrite").option("header", True).csv(out)
    t2 = time.time()
    print("SPARK_CM session_start_s=%.1f job_s=%.1f" % (t1 - t0, t2 - t1))
    spark.stop()


if __name__ == "__main__":
    main()
