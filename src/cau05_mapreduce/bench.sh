#!/usr/bin/env bash
# Cau 5 - Do thoi gian job chinh (danh muc x tinh x thang) co/khong Combiner, lap N lan.
#   cd ~/src/cau05_mapreduce && bash bench.sh [N=3]     -> output/bench.tsv
# Can chay run.sh truoc (de co build/cau05.jar va du lieu raw). Ket qua phu thuoc tai cua cum
# luc chay (cac job khac dung chung YARN), nen ghi kem thoi diem chay.
set -euo pipefail
cd "$(dirname "$0")"

N=${1:-3}
IN=/btl/raw/orders/ingest_date=${SNAPSHOT:-2026-08-01}/orders.csv
TMPOUT=/btl/output/cau05_mr/_bench
[ -f build/cau05.jar ] || bash build.sh > /dev/null

echo "# $(date '+%Y-%m-%d %H:%M:%S') - $N lan moi cau hinh, 1 map, 3 reduce" > output/bench.tsv
printf 'combiner\tlan\telapsed_ms\treduce_shuffle_bytes\tspilled_records\n' >> output/bench.tsv
for i in $(seq 1 "$N"); do
  for comb in true false; do
    r=$(hadoop jar build/cau05.jar btl.cau05.RevenueReturnJob -D cau05.combiner="$comb" \
          "$IN" "$TMPOUT" 2> /dev/null)
    ms=$(awk -F'\t' '$1 == "ELAPSED_MS" { print $2 }' <<< "$r")
    sb=$(awk -F'\t' '$1 == "COUNTER" && $3 == "REDUCE_SHUFFLE_BYTES" { print $4 }' <<< "$r")
    sp=$(awk -F'\t' '$1 == "COUNTER" && $3 == "SPILLED_RECORDS" { print $4 }' <<< "$r")
    printf '%s\t%s\t%s\t%s\t%s\n' "$comb" "$i" "$ms" "$sb" "$sp" | tee -a output/bench.tsv
  done
done
hdfs dfs -rm -r -f -skipTrash "$TMPOUT" > /dev/null
awk -F'\t' 'NR > 2 { s[$1] += $3; n[$1]++ } END { for (k in s) printf "# trung binh combiner=%s: %.0f ms\n", k, s[k] / n[k] }' \
  output/bench.tsv | sort | tee -a output/bench.tsv
