#!/usr/bin/env bash
# Chuan bi truoc buoi demo (chay trong ssh may1):  bash ~/src/demo/cau00_chuan_bi.sh
# Bat cum (phan nao dang chay thi bo qua), kiem tra 8 dich vu, nap ban chup chuan vao /btl/raw.
# shellcheck source=lib.sh disable=SC1091
. "$(dirname "$0")/lib.sh"
cd "$SRC" || exit 1

tieude "Chuan bi cum: HDFS, YARN, JobHistory, Spark History, HBase"
buoc "Bat cum"
lenh 'start-cluster.sh'
buoc "Kiem tra cum (phai ra 8 PASS)"
lenh 'smoke-test.sh'
buoc "Tao 4 vung /btl va nap ban chup chuan ingest_date=2026-08-01"
lenh 'bash cau03_hdfs/init_zones.sh'
lenh 'hdfs dfs -ls /btl'
web "HDFS http://localhost:9870 | YARN http://localhost:8088 | HBase http://localhost:16010"
