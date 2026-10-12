#!/usr/bin/env bash
# Cau 6 - chay pipeline Spark day du tren YARN va ghi thoi gian vao output/.
#   bash cau06_spark/run.sh            # pipeline (ghi curated + output + output/*.csv)
#   bash cau06_spark/run.sh --bench    # them thu nghiem hieu nang (khoang 10-15 phut)
#   bash cau06_spark/run.sh --cm-only  # chi do job category x month (doi chung voi 1 job MR Cau 5)
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p output

bash ../cau03_hdfs/init_zones.sh > /dev/null   # dam bao co ban chup raw (idempotent)

t0=$(date +%s.%N)
spark-submit pipeline.py > output/spark-submit.log 2>&1 || { tail -40 output/spark-submit.log; exit 1; }
t1=$(date +%s.%N)
wall=$(awk -v a="$t0" -v b="$t1" 'BEGIN { printf "%.1f", b - a }')
# moi lan chay them mot dong (cum dung chung -> thoi gian dao dong theo tai cua nhom khac)
if [ ! -s output/run_time.txt ] || ! head -1 output/run_time.txt | grep -q "^date_utc"; then
  echo "date_utc,wall_clock_s,yarn_apps_khac_dang_chay  # spark-submit pipeline.py: YARN client, 2 executor x 1g, shuffle.partitions=12; gom khoi dong, doc raw, ghi curated + output" \
    > output/run_time.txt
fi
others=$(yarn application -list 2>/dev/null | grep -c "^application_" || true)
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ),$wall,$others" | tee -a output/run_time.txt
grep -E "^(orders raw|curated|KET QUA)" output/pipeline_log.txt
rm -f output/spark-submit.log
# dung luong ket qua tren HDFS (byte 1 ban sao, byte x3 ban sao, duong dan)
{ hdfs dfs -du -s /btl/curated/orders; hdfs dfs -du /btl/output/cau06_spark; } > output/hdfs_outputs.txt

MODE=${1:-}
if [ "$MODE" = "--bench" ]; then
  spark-submit bench.py --scales 1,10 --reps 3 > output/bench.log 2>&1 || { tail -40 output/bench.log; exit 1; }
  grep -E "^(BENCH|RESULT)" output/bench.log > output/bench_spark.txt
  rm -f output/bench.log
  cat output/bench_spark.csv
fi
if [ "$MODE" = "--bench" ] || [ "$MODE" = "--cm-only" ]; then
  # 3 lan spark-submit category_month_only.py: thoi gian tinh ca khoi dong ung dung tren YARN
  echo "spark-submit category_month_only.py: doc orders.csv, lam sach, groupBy category x month, ghi CSV" \
    > output/category_month_only.txt
  for i in 1 2 3; do
    a=$(date +%s.%N)
    line=$(spark-submit category_month_only.py --out "/tmp/cau06_cm_only_$$" 2>&1 | grep "^CM_ONLY") \
      || { echo "FAIL: category_month_only.py"; exit 1; }
    b=$(date +%s.%N)
    echo "lan $i: wall_s=$(awk -v a="$a" -v b="$b" 'BEGIN { printf "%.1f", b - a }') $line" \
      | tee -a output/category_month_only.txt
  done
  hdfs dfs -rm -r -f -skipTrash "/tmp/cau06_cm_only_$$" > /dev/null 2>&1 || true
fi
