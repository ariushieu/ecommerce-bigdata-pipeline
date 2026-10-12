#!/usr/bin/env bash
# Cau 2 - Kich ban (i): nap orders/customers/products theo lo bang Flume spooldir
# -> FileChannel -> HDFS /btl/raw/<bang>/ingest_date=<hom nay>/.
# Kiem tra tep tren HDFS trung tung byte voi tep goc, ghi log vao output/.
#   bash cau02_flume/run_batch.sh
# Chay lai trong ngay: xoa cac tep Flume nap lan truoc (ten <bang>_*), KHONG
# dung vao ban chup ingest_date=2026-08-01 (tep ten <bang>.csv).
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source=lib.sh disable=SC1091
. ./lib.sh

DATA=${DATA_DIR:-/data}
OUT=${OUT_DIR:-output}
LOG=$OUT/batch_run.txt
BANG=(orders customers products)
mkdir -p "$OUT" "$WORK"
CONF=$WORK/batch-csv.conf
sinh_conf conf/batch-csv.conf "$CONF"

AGENT_PID=
trap 'tat_agent "$AGENT_PID"' EXIT
exec > >(tee "$LOG") 2>&1

echo "# Cau 2 - kich ban (i) spooldir -> FileChannel -> HDFS   ($(date '+%F %T %z'))"
echo "# conf: conf/batch-csv.conf   agent: b1   raw: $RAW"

echo "== 1. Don lan chay truoc (chi tep do Flume tao)"
for t in "${BANG[@]}"; do
  rm -rf "${WORK:?}/spool/$t"; mkdir -p "$WORK/spool/$t"
  hdfs dfs -rm -f -skipTrash "$RAW/$t/ingest_date=*/${t}_*" "$RAW/$t/ingest_date=*/_${t}_*" 2>/dev/null | sed 's/^/   /' || true
done

echo "== 2. Bat agent b1"
bat_agent b1 "$CONF" "$WORK/log-batch"
sleep 5
kill -0 "$AGENT_PID" || { echo "FAIL: agent khong chay"; tail -30 "$WORK/log-batch/stdout.log"; exit 1; }

echo "== 3. Dat tep lo vao spool (chep ten *.tmp roi mv: nguyen tu, ten khong lap)"
LO=$(date +%Y%m%d-%H%M%S)
T0=$(date +%s%N)
for t in "${BANG[@]}"; do
  cp "$DATA/$t.csv" "$WORK/spool/$t/${t}_$LO.tmp"
  mv "$WORK/spool/$t/${t}_$LO.tmp" "$WORK/spool/$t/${t}_$LO"
  echo "   $WORK/spool/$t/${t}_$LO  ($(stat -c %s "$DATA/$t.csv") byte)"
done

da_doc_xong() { for t in "${BANG[@]}"; do [ -e "$WORK/spool/$t/${t}_$LO.COMPLETED" ] || return 1; done; }
da_dong_tep() {  # 3 tep da dong (khong con _*.tmp)
  local n
  n=$(hdfs dfs -ls "$RAW/*/ingest_date=*/*_$LO.*.csv" 2>/dev/null | grep -c "^-" || true)
  [ "$n" = 3 ] && ! hdfs dfs -ls "$RAW/*/ingest_date=*/_*_$LO.*" >/dev/null 2>&1
}
cho_dk 120 da_doc_xong || { echo "FAIL: spooldir chua doc xong sau 120 s"; exit 1; }
T1=$(date +%s%N)
echo "   source doc xong (doi ten .COMPLETED) sau $(( (T1 - T0) / 1000000 )) ms"
cho_dk 120 da_dong_tep || { echo "FAIL: HDFS sink chua dong tep sau 120 s"; exit 1; }
T2=$(date +%s%N)
echo "   sink dong tep (idleTimeout 30 s) sau $(( (T2 - T0) / 1000000 )) ms"

echo "== 4. Tat agent"
tat_agent "$AGENT_PID"; AGENT_PID=

echo "== 5. Kiem tra tren HDFS"
hdfs dfs -ls "$RAW/*/ingest_date=*/*_$LO.*.csv" | awk '{print "   " $1, $2, $5, $8}'
printf '   %-10s %10s %10s %8s %8s  %s\n' bang byte_goc byte_hdfs dong_goc dong_hdfs md5
LOI=0
for t in "${BANG[@]}"; do
  f=$(hdfs dfs -ls "$RAW/$t/ingest_date=*/${t}_$LO.*.csv" | awk '/^-/{print $8}')
  m1=$(md5sum < "$DATA/$t.csv" | cut -c1-32)
  m2=$(hdfs dfs -cat "$f" | md5sum | cut -c1-32)
  b2=$(hdfs dfs -stat %b "$f")
  l1=$(wc -l < "$DATA/$t.csv")
  l2=$(hdfs dfs -cat "$f" | wc -l)
  r=$(hdfs dfs -stat %r "$f")
  if [ "$m1" = "$m2" ]; then kq="trung khop"; else kq="KHAC"; LOI=1; fi
  printf '   %-10s %10s %10s %8s %8s  %s (replication=%s)\n' "$t" "$(stat -c %s "$DATA/$t.csv")" "$b2" "$l1" "$l2" "$kq" "$r"
done
echo "   BOM o dau tep orders tren HDFS: $(hdfs dfs -cat "$RAW/orders/ingest_date=*/orders_$LO.*.csv" 2>/dev/null | head -c 3 | od -An -tx1 | tr -s ' ')"
echo "   Ban chup chuan van con nguyen:"
hdfs dfs -ls "$RAW/*/ingest_date=2026-08-01/" 2>/dev/null | awk '/^-/{print "     " $5, $8}' \
  || echo "     (khong co ban chup duoi $RAW - chay cau03_hdfs/init_zones.sh)"
if [ "$LOI" = 0 ]; then
  echo "PASS: 3 tep lo nap vao HDFS trung tung byte voi tep goc"
else
  echo "FAIL: noi dung khac tep goc"; exit 1
fi
