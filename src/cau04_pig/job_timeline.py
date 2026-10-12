#!/usr/bin/env python3
# Cau 4 - Lay moc thoi gian cua cac job MapReduce do Pig sinh ra tu JobHistory REST API
# (http://masternode:19888/ws/v1/history/mapreduce/jobs/<id>), tach thoi gian cho YARN cap
# tai nguyen (cho) va thoi gian job chay that.
#   python3 job_timeline.py output/pig_job_stats.txt > output/pig_job_timeline.tsv
import json
import re
import sys
import urllib.request

HIST = "http://masternode:19888/ws/v1/history/mapreduce/jobs/"


def main():
    text = open(sys.argv[1], encoding="utf-8").read()
    # Bang "Job Stats": JobId Maps Reduces ... Alias Feature Outputs
    alias = {}
    for line in text.splitlines():
        f = line.split("\t")
        if f[0].startswith("job_") and len(f) >= 10:
            alias[f[0]] = (f[-3], f[-2])
    jobs = sorted(alias)
    rows = []
    for j in jobs:
        with urllib.request.urlopen(HIST + j, timeout=10) as r:
            d = json.load(r)["job"]
        rows.append((j, d["mapsTotal"], d["reducesTotal"],
                     (d["startTime"] - d["submitTime"]) / 1000.0,
                     (d["finishTime"] - d["startTime"]) / 1000.0,
                     d["submitTime"], d["finishTime"]))
    print("job_id\tmaps\treduces\twait_s\trun_s\tfeature\talias")
    for j, m, r, w, run, _, _ in rows:
        al, feat = alias[j]
        print("%s\t%d\t%d\t%.1f\t%.1f\t%s\t%s" % (j, m, r, w, run, feat, re.sub(r"\s+", "", al)[:80]))
    if rows:
        span = (max(x[6] for x in rows) - min(x[5] for x in rows)) / 1000.0
        print("# %d job; tong wait_s %.1f; tong run_s %.1f; tu job dau nop den job cuoi xong %.1f s"
              % (len(rows), sum(x[3] for x in rows), sum(x[4] for x in rows), span))


if __name__ == "__main__":
    main()
