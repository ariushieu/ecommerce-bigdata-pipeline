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

kv() { awk -F'\t' -v k="$1" '$1 == k { print $2 }' output/checks.tsv; }
kq "Lam sach: $(kv raw_status_OK) OK + $(kv raw_status_MISSING) MISSING giu lai = $(kv 'split_clean_orders (staging)') don sach; loai $(kv split_rejected_orders) don (OUTLIER, DUPLICATE, LATE)"
kq "JOIN voi bang khach hang + san pham: $(kv join_enriched_orders) don, lech danh muc: $(kv join_catalog_mismatch)"
kq "$(head -1 output/runtime.txt | awk -F'\t' '{ sub("wall_s=", "", $2); sub("mapreduce_jobs=", "", $3); print "Thoi gian: " $2 " s, Pig sinh " $3 " job MapReduce" }')"
while IFS= read -r d; do kq "$d"; done < <(grep -E '^orders=|giong het|khac nhau' output/runtime.txt)
kq "Ket qua tren HDFS: $OUT (7 thu muc), staging: /btl/staging/orders"
web http://localhost:8088  "YARN: cac job PigLatin:cau04.pig (FINISHED)"
web http://localhost:19888 "JobHistory: 17 job MapReduce do Pig sinh ra"
web http://localhost:9870  "HDFS: Utilities > Browse the file system > /btl/output/cau04_pig"
tong_ket
