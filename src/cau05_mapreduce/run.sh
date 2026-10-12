#!/usr/bin/env bash
# Cau 5 - Chay 3 job MapReduce tren cum (YARN) voi ban chup chuan, luu ket qua nho vao output/.
#   cd ~/src/cau05_mapreduce && bash run.sh
# 1) category_province_month             (co Combiner, 3 reducer)  -> ket qua chinh cua Cau 5
# 2) category_province_month_nocombiner  (tat Combiner)            -> so sanh counter
# 3) category_month                      (gop len danh muc x thang) -> compare_category_month.csv
set -euo pipefail
cd "$(dirname "$0")"

SNAP=${SNAPSHOT:-2026-08-01}
IN=/btl/raw/orders/ingest_date=$SNAP/orders.csv
OUT=/btl/output/cau05_mr
LOG=${TMPDIR:-/tmp}/cau05_logs
mkdir -p output "$LOG"

bash ../cau03_hdfs/init_zones.sh > /dev/null   # dam bao co ban chup raw (idempotent)
JAR=$(bash build.sh | sed -n "s/^JAR=//p")
hdfs dfs -mkdir -p "$OUT"

: > output/runtime.txt
chay() {  # chay <ten> [-D ...]
  local ten=$1; shift
  local t0 t1
  echo "== $ten"
  t0=$(date +%s.%N)
  hadoop jar "$JAR" btl.cau05.RevenueReturnJob "$@" "$IN" "$OUT/$ten" \
    > "output/counters_$ten.txt" 2> "$LOG/$ten.log"
  t1=$(date +%s.%N)
  printf '%s\twall_s=%s\t%s\n' "$ten" "$(awk -v a="$t0" -v b="$t1" 'BEGIN { printf "%.1f", b - a }')" \
    "$(grep -E '^(ELAPSED_MS|JOB_ID)' "output/counters_$ten.txt" | paste -sd' ')" | tee -a output/runtime.txt
}

chay category_province_month
chay category_province_month_nocombiner -D cau05.combiner=false
chay category_month -D cau05.level=category_month

hdfs dfs -cat "$OUT/category_province_month/part-r-*" > output/category_province_month.tsv
{ echo "category,month,orders,net_revenue,returned,return_rate_pct"
  hdfs dfs -cat "$OUT/category_month/part-r-*" | tr '\t' ','; } > output/compare_category_month.csv

# Kiem tra: co/khong Combiner cho cung ket qua
if diff -q output/category_province_month.tsv \
     <(hdfs dfs -cat "$OUT/category_province_month_nocombiner/part-r-*") > /dev/null; then
  echo "Combiner bat/tat: ket qua giong het nhau" | tee -a output/runtime.txt
else
  echo "CANH BAO: ket qua co/khong Combiner khac nhau" | tee -a output/runtime.txt
fi

# Tep part-r-* cua tung reducer: so dong, danh muc
{ echo "part_file	lines	orders	categories"
  for p in 0 1 2; do
    f="$OUT/category_province_month/part-r-0000$p"
    hdfs dfs -cat "$f" | awk -F'\t' -v f="part-r-0000$p" \
      '{ n++; o += $4; c[$1] = 1 } END { s = ""; for (k in c) s = s (s ? "," : "") k; print f "\t" n "\t" o "\t" s }'
  done; } > output/partitions.txt
python3 -I partition_balance.py output/category_province_month.tsv > output/partition_balance.txt

echo "== Tong (doi chieu Cau 1)"
awk -F, 'NR > 1 { n += $3; r += $4; t += $5 } END { printf "orders=%d net_revenue=%.2f returned=%d\n", n, r, t }' \
  output/compare_category_month.csv | tee -a output/runtime.txt

bash summarize.sh > /dev/null
