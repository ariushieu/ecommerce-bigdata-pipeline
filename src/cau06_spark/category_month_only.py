#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Cau 6 - ban Spark cua DUNG MOT job MapReduce cua Cau 5 (category x month) de so thoi gian:
doc orders.csv -> lam sach -> groupBy (Spark SQL) -> ghi CSV len HDFS. Khong cache, khong join.

  spark-submit cau06_spark/category_month_only.py [--out /tmp/cau06_cm_only]
"""
import argparse
import time

from pyspark.sql import SparkSession

import pipeline as P


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="/tmp/cau06_cm_only")
    args = ap.parse_args()
    t0 = time.time()
    spark = SparkSession.builder.appName("cau06-category-month-only").getOrCreate()
    t1 = time.time()
    orders, _, _, _ = P.read_sources(spark, P.SNAPSHOT)
    P.clean_orders(orders).createOrReplaceTempView("orders_clean")
    cm = P.category_month_sql(spark, "orders_clean")
    cm.coalesce(1).write.mode("overwrite").option("header", True).csv(args.out)   # action duy nhat
    t2 = time.time()
    n = spark.read.option("header", True).csv(args.out).count()
    print("CM_ONLY rows=%d session_start_s=%.1f job_s=%.1f" % (n, t1 - t0, t2 - t1))
    spark.stop()


if __name__ == "__main__":
    main()
