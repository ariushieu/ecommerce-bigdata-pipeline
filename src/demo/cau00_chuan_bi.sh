#!/usr/bin/env bash
# Chuan bi truoc buoi demo (chay trong ssh may1):  bash ~/src/demo/cau00_chuan_bi.sh
# Bat cum (phan nao dang chay thi bo qua), kiem tra 8 dich vu, nap ban chup chuan vao /btl/raw.
# shellcheck source=lib.sh disable=SC1091
. "$(dirname "$0")/lib.sh"
cd "$SRC" || exit 1
SMOKE=$(mktemp)
trap 'rm -f "$SMOKE"' EXIT

tieude "Chuan bi cum: HDFS, YARN, JobHistory, Spark History, HBase"
buoc "Bat cum"
lenh 'start-cluster.sh'
buoc "Kiem tra cum (phai ra 8 PASS)"
lenh "smoke-test.sh | tee $SMOKE"
buoc "Tao 4 vung /btl va nap ban chup chuan ingest_date=2026-08-01"
lenh "bash cau03_hdfs/init_zones.sh | sed '/^== Cay thu muc/,\$d'"
lenh 'hdfs dfs -ls /btl/raw /btl/staging /btl/curated /btl/output'

kq "Smoke test: $(grep -oE '[0-9]+ PASS, [0-9]+ FAIL' "$SMOKE" | tail -1)"
kq "HDFS: $(hdfs dfsadmin -report 2>/dev/null | grep -m1 '^Live datanodes' | tr -d ':')"
kq "YARN: $(yarn node -list 2>/dev/null | grep -c RUNNING) NodeManager RUNNING"
kq "Ban chup chuan: $(hdfs dfs -ls '/btl/raw/*/ingest_date=2026-08-01/' 2>/dev/null | grep -c '^-') tep trong /btl/raw/*/ingest_date=2026-08-01"
web http://localhost:9870  "HDFS: Datanodes (3 node), Utilities > Browse the file system > /btl"
web http://localhost:8088  "YARN: danh sach job"
web http://localhost:19888 "JobHistory: job MapReduce, Counters"
web http://localhost:18080 "Spark History: job Spark"
web http://localhost:16010 "HBase: bang, region, RegionServer"
web http://localhost:8787  "RStudio: Cau 8, 9"
tong_ket
