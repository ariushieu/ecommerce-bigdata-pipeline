#!/usr/bin/env bash
# Cau 4 - Chay cau04.pig tren cum (mapreduce mode, YARN) voi ban chup chuan,
# roi chep ket qua nho ve output/.
#   cd ~/src/cau04_pig && bash run.sh
set -euo pipefail
cd "$(dirname "$0")"

SNAP=${SNAPSHOT:-2026-08-01}
RAW=/btl/raw
STAGING=/btl/staging/orders
OUT=/btl/output/cau04_pig
LOG=${TMPDIR:-/tmp}/cau04_logs
mkdir -p output "$LOG"

bash ../cau03_hdfs/init_zones.sh > /dev/null   # dam bao co ban chup raw (idempotent)

echo "== pig -x mapreduce -f cau04.pig"
t0=$(date +%s.%N)
pig -x mapreduce -param SNAP="$SNAP" -param RAW="$RAW" -param STAGING="$STAGING" -param OUT="$OUT" \
  -f cau04.pig > output/describe.txt 2> "$LOG/pig.log" \
  || { grep -E "ERROR" "$LOG/pig.log" | head -20; exit 1; }
t1=$(date +%s.%N)
rm -f pig_*.log

# Bang thong ke Pig in ra cuoi log (HadoopVersion ... Job DAG), bo cac dong log co ngay gio
awk '/^HadoopVersion/ { on = 1 } on && /^20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] / { exit } on { print }' \
  "$LOG/pig.log" > output/pig_job_stats.txt
grep -E "Encountered Warning|Pig script completed" "$LOG/pig.log" | sed 's/^.* - //' >> output/pig_job_stats.txt
NJOBS=$(awk '/^Job Stats/ { on = 1; next } on && /^job_/ { n++ } on && /^Input\(s\)/ { exit } END { print n + 0 }' \
  output/pig_job_stats.txt)
{ printf 'cau04.pig\twall_s=%s\tmapreduce_jobs=%s\n' \
    "$(awk -v a="$t0" -v b="$t1" 'BEGIN { printf "%.1f", b - a }')" "$NJOBS"; } | tee output/runtime.txt
# Thoi gian cho cap tai nguyen va thoi gian chay that cua tung job (JobHistory REST)
python3 -I job_timeline.py output/pig_job_stats.txt > output/pig_job_timeline.tsv
tail -1 output/pig_job_timeline.tsv | tee -a output/runtime.txt


# Chep ket qua ve may (1 lenh -get thay cho nhieu lenh -cat, moi lenh hdfs mat ~2 s khoi dong JVM)
L="$LOG/hdfs"
rm -rf "$L" && mkdir -p "$L"
hdfs dfs -get "$OUT" "$L/out"
hdfs dfs -get "$STAGING" "$L/staging"
hdfs dfs -get "$RAW/orders/ingest_date=$SNAP/orders.csv" "$L/orders.csv"

# Ket qua nho: tieu de lay tu .pig_header (PigStorage '-schema') nen luon khop voi script
lay() {  # lay <ten_ket_qua> <tep_dich> [sort]
  cat "$L/out/$1/.pig_header" > "$2"
  if [ "${3:-}" = sort ]; then
    cat "$L/out/$1"/part-* | LC_ALL=C sort >> "$2"
  else
    cat "$L/out/$1"/part-* >> "$2"
  fi
}
lay compare_category_month output/compare_category_month.csv
lay segment_stats output/segment_stats.tsv
lay category_summary output/category_summary.tsv
lay top10_products output/top10_products.tsv
lay event_check output/event_check.tsv sort
lay checks output/checks.tsv sort
printf 'split_clean_orders (staging)\t%s\nsplit_rejected_orders\t%s\n' \
  "$(cat "$L/staging"/part-* | wc -l)" "$(cat "$L/out/rejected_orders"/part-* | wc -l)" >> output/checks.tsv

# Vi du truoc/sau lam sach cho bao cao (muc 2.4.1): don OK, don MISSING (o trong), don OUTLIER
IDS='ORD0000001|ORD0000174|ORD0000025'
{ echo "### raw: $RAW/orders/ingest_date=$SNAP/orders.csv (CSV, BOM, CRLF)"
  echo "16 byte dau tep:"
  od -c -N 16 "$L/orders.csv" | head -2
  grep -E "^($IDS)," "$L/orders.csv" | tr -d '\r'
  echo
  echo "### staging: $STAGING (TSV, khong tieu de; ten cot trong .pig_header)"
  cat "$L/staging/.pig_header"
  grep -hE "^($IDS)	" "$L/staging"/part-* || true
  echo
  echo "### rejected: $OUT/rejected_orders (them cot status)"
  grep -hE "^($IDS)	" "$L/out/rejected_orders"/part-* || true
  echo
  echo "### dung luong (byte) va so dong"
  printf 'raw orders.csv\t%s byte\t%s dong\n' "$(wc -c < "$L/orders.csv")" "$(wc -l < "$L/orders.csv")"
  printf 'staging orders\t%s byte\t%s dong\t%s tep part\n' \
    "$(cat "$L/staging"/part-* | wc -c)" "$(cat "$L/staging"/part-* | wc -l)" \
    "$(find "$L/staging" -name 'part-*' | wc -l)"
} > output/staging_before_after.txt
rm -rf "$L"


echo "== Tong (doi chieu Cau 1)"
awk -F, 'NR > 1 { n += $3; c += $4 * 100; r += $5 } END { printf "orders=%d net_revenue=%.2f returned=%d\n", n, c / 100, r }' \
  output/compare_category_month.csv | tee -a output/runtime.txt
if [ -f ../cau05_mapreduce/output/compare_category_month.csv ]; then
  if diff -q output/compare_category_month.csv ../cau05_mapreduce/output/compare_category_month.csv > /dev/null; then
    echo "Pig va MapReduce: compare_category_month.csv giong het nhau" | tee -a output/runtime.txt
  else
    echo "CANH BAO: Pig va MapReduce khac nhau" | tee -a output/runtime.txt
  fi
fi
