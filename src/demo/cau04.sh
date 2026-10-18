#!/usr/bin/env bash
# Demo Cau 4 - Pig Latin (ssh may1):  bash ~/src/demo/cau04.sh   [nhanh]
# Chay day du mat khoang 6 phut (17 job MapReduce): nen bat o mot cua so rieng tu dau buoi.
# shellcheck source=lib.sh disable=SC1091
. "$(dirname "$0")/lib.sh" "$@"
cd "$SRC/cau04_pig" || exit 1
OUT=/btl/output/cau04_pig

tieude "Cau 4 - Lam sach va tong hop bang Pig Latin (bao cao muc 2.4.1, 3.5, 4.1)"

buoc "Cac buoc trong cau04.pig: LOAD, FILTER, SPLIT, FOREACH, JOIN, GROUP, ORDER, STORE"
lenh "grep -nE '^-- [0-9]|^SPLIT|JOIN .* USING' cau04.pig | cut -c1-110"

buoc "Chay cau04.pig tren YARN (pig -x mapreduce)"
chay_lau 6 'bash run.sh'

buoc "Lam sach: 15.000 don goc -> 14.408 don sach, 592 don bi loai (OUTLIER, DUPLICATE, LATE)"
lenh 'cat output/checks.tsv'

buoc "Ket qua tren HDFS"
lenh "hdfs dfs -ls $OUT"
lenh "hdfs dfs -cat $OUT/category_summary/part-*"
lenh 'cat output/top10_products.tsv'
lenh 'cat output/runtime.txt'
web "YARN http://localhost:8088 | JobHistory http://localhost:19888"
