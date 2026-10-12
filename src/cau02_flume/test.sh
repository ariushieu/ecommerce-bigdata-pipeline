#!/usr/bin/env bash
# Cau 2 - Kiem thu tu dong (CI): chay CA HAI kich ban Flume voi duong dan, cong
# va bang HBase RIENG (khong dung vao du lieu demo /btl/raw, btl:order_events):
#   (i)  run_batch.sh : 3 tep CSV -> HDFS, trung tung byte voi tep goc
#   (ii) run_stream.sh: 50 event + 1 event hong, gui lai 10 event dau
#        -> HDFS 61 dong (51 event_id), HBase 50 dong (event hong bi bo qua)
# Tu don dep moi thu da tao. Thoi gian ~3-4 phut.
set -euo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d /tmp/cau02_test.XXXXXX)
ID=$(basename "$TMP" | tr -cd 'A-Za-z0-9')
export FLUME_WORK=$TMP/work
export RAW_ROOT=/tmp/cau02_test_$ID/raw
export HTTP_PORT=${TEST_HTTP_PORT:-41499}
export MON_PORT=${TEST_MON_PORT:-34599}
export HB_TABLE=btl:cau02_test_$ID
export OUT_DIR=$TMP/out

# shellcheck source=lib.sh disable=SC1091
. ./lib.sh
# namespace btl co san chua? (neu test tu tao thi xoa lai khi xong, de khong
# anh huong script tao namespace cua Cau 7 chay sau trong CI)
CO_NS=0; hb "list_namespace" | grep -qx btl && CO_NS=1
# shellcheck disable=SC2329
don_dep() {
  pkill -f "flume.*$TMP" 2>/dev/null || true
  hb_xoa_bang "$HB_TABLE" || true
  [ "$CO_NS" = 0 ] && { hb "drop_namespace 'btl'" > /dev/null || true; }
  hdfs dfs -rm -r -f -skipTrash "/tmp/cau02_test_$ID" > /dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap don_dep EXIT

LOI=0
echo "== Kiem cu phap"
if python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' replay_events.py; then
  echo "PASS: replay_events.py dung cu phap Python 3.8"
else
  echo "FAIL: replay_events.py"; LOI=1
fi

echo "== Kich ban (i): spooldir -> FileChannel -> HDFS ($RAW_ROOT)"
if DATA_DIR=/data bash run_batch.sh > "$TMP/batch.log" 2>&1; then
  grep -E "trung khop|PASS" "$TMP/batch.log"
else
  echo "FAIL: run_batch.sh"; tail -30 "$TMP/batch.log"; LOI=1
fi

echo "== Kich ban (ii): HTTP -> FileChannel/HDFS + MemoryChannel/HBase ($HB_TABLE)"
mkdir -p "$TMP/data"
head -50 /data/events_stream.jsonl > "$TMP/data/events_stream.jsonl"
# event hong: JSON hop le nhung thieu payload -> HDFS giu, HBase bo qua
echo '{"event_id": "EVT-BAD-0001", "event_type": "order_event", "note": "thieu payload"}' >> "$TMP/data/events_stream.jsonl"
if DATA_DIR=$TMP/data RESEND=10 RATE=100 bash run_stream.sh > "$TMP/stream.log" 2>&1; then
  grep -E "REPLAY|PASS" "$TMP/stream.log"
else
  echo "FAIL: run_stream.sh"; tail -40 "$TMP/stream.log"; LOI=1
fi
if grep -q "HDFS nhan 61 dong" "$TMP/stream.log" && grep -q "HBase 50 dong" "$TMP/stream.log"; then
  echo "PASS: 61 dong HDFS, 50 dong HBase (1 event hong chi nam o HDFS)"
else
  echo "FAIL: so dong HDFS/HBase khong dung 61/50"; LOI=1
fi

exit "$LOI"
