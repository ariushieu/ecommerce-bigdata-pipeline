#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Cau 6 - Thu nghiem hieu nang (muc 4.4 bao cao).

Chay cung mot phan loi cua pipeline (doc + lam sach + join + 6 action phan tich,
KHONG ghi HDFS) trong MOT ung dung Spark, doi cau hinh giua cac lan:
  - cache (persist MEMORY_AND_DISK) / khong cache
  - spark.sql.shuffle.partitions = 12 / 200
  - quy mo x1 / x10 (hop nhieu ban orders.csv, moi ban la mot lan quet HDFS)
Moi cau hinh chay --reps lan (xen ke), lay trung vi. Chay mot lan khoi dong truoc
(bo qua) de JVM/JIT va bo dem HDFS on dinh.

  spark-submit cau06_spark/bench.py [--scales 1,10] [--reps 3] [--out cau06_spark/output]
"""
import argparse
import csv
import json
import os
import statistics
import time

from pyspark.sql import SparkSession

import pipeline as P


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser()
    ap.add_argument("--scales", default="1,10")
    ap.add_argument("--reps", type=int, default=3)
    ap.add_argument("--out", default=os.path.join(here, "output"))
    args = ap.parse_args()
    scales = [int(s) for s in args.scales.split(",")]

    spark = SparkSession.builder.appName("cau06-spark-bench").getOrCreate()
    spark.sparkContext.setLogLevel("WARN")
    metrics = P.Metrics(spark)
    configs = []
    for sc in scales:
        configs += [(sc, True, 12), (sc, False, 12), (sc, True, 200)]

    def once(tag, scale, cache, parts):
        spark.conf.set("spark.sql.shuffle.partitions", str(parts))
        spark.sparkContext.setJobGroup(tag, tag)
        t0 = time.time()
        res = P.run(spark, P.SNAPSHOT, scale, cache)
        el = time.time() - t0
        res["enriched"].unpersist(blocking=True)
        spark.catalog.clearCache()
        m = metrics.group(tag)
        n = res["n_clean"]
        print("BENCH %-28s %6.1fs n=%d jobs=%s tasks=%s in=%s shufR=%s" % (
            tag, el, n, m["jobs"], m["numTasks"], m["inputBytes"], m["shuffleReadBytes"]), flush=True)
        return el, n, m

    once("warmup", 1, True, 12)
    runs = {c: [] for c in configs}
    for rep in range(args.reps):
        for c in configs:
            sc, cache, parts = c
            tag = "x%d-%s-p%d-r%d" % (sc, "cache" if cache else "nocache", parts, rep)
            runs[c].append(once(tag, sc, cache, parts))

    rows = []
    for c in configs:
        sc, cache, parts = c
        times = [r[0] for r in runs[c]]
        m = runs[c][0][2]   # I/O giong nhau giua cac lan lap -> lay lan dau
        rows.append({
            "scale": sc, "rows_raw": 15000 * sc, "rows_clean": runs[c][0][1],
            "cache": "yes" if cache else "no", "shuffle_partitions": parts,
            "median_s": round(statistics.median(times), 1),
            "min_s": round(min(times), 1), "max_s": round(max(times), 1),
            "jobs": m["jobs"], "stages": m["stages"], "tasks": m["numTasks"],
            "input_mb": round(m["inputBytes"] / 1e6, 2),
            "shuffle_read_mb": round(m["shuffleReadBytes"] / 1e6, 2),
            "shuffle_write_mb": round(m["shuffleWriteBytes"] / 1e6, 2),
            "spill_disk_mb": round(m["diskBytesSpilled"] / 1e6, 2),
        })
    os.makedirs(args.out, exist_ok=True)
    path = os.path.join(args.out, "bench_spark.csv")
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()), lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
    with open(os.path.join(args.out, "bench_spark_runs.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"app": spark.sparkContext.applicationId, "reps": args.reps,
                   "runs": {"x%d-%s-p%d" % (c[0], "cache" if c[1] else "nocache", c[2]):
                            [round(r[0], 2) for r in runs[c]] for c in configs}}, f, indent=2)
        f.write("\n")
    for r in rows:
        print("RESULT", json.dumps(r))
    spark.stop()


if __name__ == "__main__":
    main()
