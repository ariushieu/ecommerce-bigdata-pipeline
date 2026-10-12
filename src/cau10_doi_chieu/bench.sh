#!/usr/bin/env bash
# Cau 10 - Do thoi gian cung mot phep tinh (doanh thu, ty le tra theo category x thang)
# bang Pig, MapReduce va Spark, o 2 quy mo: x1 (15.000 don) va x10 (150.000 don).
# Chay khi cum ranh (khong co job YARN khac) de so sanh cong bang.
#   cd ~/src/cau10_doi_chieu && bash bench.sh [so_lan=3]
set -euo pipefail
cd "$(dirname "$0")"

LAN=${1:-3}
SNAP=${SNAPSHOT:-2026-08-01}
RAW=/btl/raw/orders/ingest_date=$SNAP/orders.csv
TMP=/btl/tmp/cau10
LOG=${TMPDIR:-/tmp}/cau10_logs
mkdir -p output "$LOG"

bash ../cau03_hdfs/init_zones.sh > /dev/null
bash ../cau05_mapreduce/build.sh > /dev/null
hdfs dfs -mkdir -p "$TMP"

# Ban x10: 1 dong tieu de + 10 lan phan than (ket qua dung = 10 lan so don/doanh thu)
if ! hdfs dfs -test -e "$TMP/x10/orders.csv"; then
  local_x10="$LOG/orders_x10.csv"
  hdfs dfs -get -f "$RAW" "$LOG/orders_x1.csv"
  head -n 1 "$LOG/orders_x1.csv" > "$local_x10"
  for _ in $(seq 10); do tail -n +2 "$LOG/orders_x1.csv" >> "$local_x10"; done
  hdfs dfs -mkdir -p "$TMP/x10"
  hdfs dfs -put -f "$local_x10" "$TMP/x10/orders.csv"
fi

dang_chay() { yarn application -list -appStates RUNNING,ACCEPTED 2>/dev/null | grep -c '^application_' || true; }

do_tg() {  # do_tg <cong_cu> <quy_mo> <lan> <lenh...>
  local tool=$1 scale=$2 i=$3; shift 3
  local khac t0 t1
  khac=$(dang_chay)
  t0=$(date +%s.%N)
  "$@" > "$LOG/$tool-$scale-$i.out" 2> "$LOG/$tool-$scale-$i.err"
  t1=$(date +%s.%N)
  printf '%s\t%s\t%s\t%s\t%s\n' "$tool" "$scale" "$i" \
    "$(awk -v a="$t0" -v b="$t1" 'BEGIN { printf "%.1f", b - a }')" "$khac" | tee -a output/bench.tsv
}

printf 'tool\tscale\trun\twall_s\tyarn_apps_khac\n' > output/bench.tsv
for scale in x1 x10; do
  if [ "$scale" = x1 ]; then IN=$RAW; else IN=$TMP/x10/orders.csv; fi
  for i in $(seq "$LAN"); do
    hdfs dfs -rm -r -f -skipTrash "$TMP/out_mr" "$TMP/out_pig" "$TMP/out_spark" > /dev/null 2>&1 || true
    do_tg MapReduce "$scale" "$i" hadoop jar ../cau05_mapreduce/build/cau05.jar btl.cau05.RevenueReturnJob \
      -D cau05.level=category_month "$IN" "$TMP/out_mr"
    do_tg Pig "$scale" "$i" pig -x mapreduce -param IN="$IN" -param OUT="$TMP/out_pig" -f category_month.pig
    do_tg Spark "$scale" "$i" spark-submit --master yarn --py-files ../cau06_spark/pipeline.py \
      spark_category_month.py "$IN" "$TMP/out_spark"
  done
  # Ba cong cu phai ra cung ket qua o moi quy mo
  hdfs dfs -cat "$TMP/out_mr/part-r-*" | tr '\t' ',' > "$LOG/mr.csv"
  hdfs dfs -cat "$TMP/out_pig/part-*" > "$LOG/pig.csv"
  hdfs dfs -cat "$TMP/out_spark/part-*" | tail -n +2 > "$LOG/spark.csv"
  if diff -q "$LOG/mr.csv" "$LOG/pig.csv" > /dev/null && diff -q "$LOG/mr.csv" "$LOG/spark.csv" > /dev/null; then
    echo "# $scale: 3 cong cu cho ket qua giong het nhau ($(wc -l < "$LOG/mr.csv") o)" | tee -a output/bench.tsv
  else
    echo "# $scale: CANH BAO ket qua khac nhau" | tee -a output/bench.tsv
  fi
  awk -F, -v s="$scale" '{ n += $3; r += $4; t += $5 } END { printf "# %s: orders=%d net_revenue=%.2f returned=%d\n", s, n, r, t }' \
    "$LOG/mr.csv" | tee -a output/bench.tsv
done

# So job MapReduce ma Pig sinh ra cho ban x1 (doc tu log lan chay cuoi)
grep -o 'job_[0-9_]*' "$LOG/Pig-x1-$LAN.err" | sort -u | wc -l | sed 's/^/# Pig x1: so job MapReduce sinh ra = /' | tee -a output/bench.tsv
hdfs dfs -rm -r -f -skipTrash "$TMP/out_mr" "$TMP/out_pig" "$TMP/out_spark" > /dev/null 2>&1 || true

echo "== Trung binh"
awk -F'\t' 'NR > 1 && $1 !~ /^#/ { k = $1 "\t" $2; s[k] += $4; n[k]++ }
  END { for (k in s) printf "%s\t%.1f\n", k, s[k] / n[k] }' output/bench.tsv | sort | tee output/bench_avg.tsv
