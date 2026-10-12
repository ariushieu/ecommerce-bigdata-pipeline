#!/usr/bin/env bash
# Cau 2 - Kich ban (ii): HTTP source -> (FileChannel -> HDFS) + (MemoryChannel -> HBase)
#   Lan 1: phat lai toan bo 5.000 order_event, nhip 250 event/s, lo 50 event.
#   Lan 2: gui LAI 1.000 event dau, nhanh nhat co the (mo phong client gui lai
#          sau loi mang) -> HDFS co trung, HBase van 5.000 dong (rowkey idempotent).
# Kiem tra so dong HDFS/HBase, so event_id khac nhau, ghi log + metrics vao output/.
#   bash cau02_flume/run_stream.sh
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source=lib.sh disable=SC1091
. ./lib.sh

DATA=${DATA_DIR:-/data}
OUT=${OUT_DIR:-output}
RATE=${RATE:-250}
LOG=$OUT/stream_run.txt
mkdir -p "$OUT" "$WORK"
CONF=$WORK/stream-events.conf
sinh_conf conf/stream-events.conf "$CONF"
N_SRC=$(grep -c . "$DATA/events_stream.jsonl")
RESEND=${RESEND:-1000}                     # so event dau tep gui lai o lan 2
N_RESEND=$(( RESEND < N_SRC ? RESEND : N_SRC ))
# so dong khop regex cua serializer HBase (dong khong khop chi nam o HDFS raw)
N_HB=$(python3 -c '
import re, sys
rx = re.compile(sys.argv[1])
print(sum(1 for l in open(sys.argv[2], encoding="utf-8") if rx.match(l.rstrip("\r\n"))))' \
  "$(sed -n 's/^s1.sinks.hbaseEvents.serializer.regex = //p' "$CONF")" "$DATA/events_stream.jsonl")

AGENT_PID=
trap 'tat_agent "$AGENT_PID"' EXIT
exec > >(tee "$LOG") 2>&1

metrics() {  # in bang so lieu JSON metrics cua agent (counter cua source/channel/sink)
  curl -s "http://localhost:$MON_PORT/metrics" | python3 -c '
import json, sys
m = json.load(sys.stdin)
keys = ["EventReceivedCount", "EventAcceptedCount", "EventPutSuccessCount",
        "EventTakeSuccessCount", "ChannelSize", "ChannelCapacity", "ChannelFillPercentage",
        "EventDrainAttemptCount", "EventDrainSuccessCount", "BatchCompleteCount", "BatchUnderflowCount",
        "ConnectionFailedCount", "EventWriteFail", "ChannelWriteFail"]
for comp in sorted(m):
    vals = ["%s=%s" % (k, m[comp][k]) for k in keys if k in m[comp]]
    print("   %-22s %s" % (comp, " ".join(vals)))'
}
# shellcheck disable=SC2329
kenh_rong() {  # ca hai channel da duoc sink lay het
  curl -s "http://localhost:$MON_PORT/metrics" | python3 -c '
import json, sys
m = json.load(sys.stdin)
sys.exit(0 if all(m[c]["ChannelSize"] == "0" for c in m if c.startswith("CHANNEL.")) else 1)'
}

echo "# Cau 2 - kich ban (ii) HTTP -> FileChannel/HDFS + MemoryChannel/HBase   ($(date '+%F %T %z'))"
echo "# conf: conf/stream-events.conf  agent: s1  cong: $HTTP_PORT  bang: $HB_TABLE  raw: $RAW/events"

echo "== 1. Chuan bi: xoa tep Flume cu (events.*), tao/truncate bang HBase"
hdfs dfs -rm -f -skipTrash "$RAW/events/ingest_date=*/events.*" "$RAW/events/ingest_date=*/_events.*" 2>/dev/null | sed 's/^/   /' || true
hb_tao_bang "$HB_TABLE" | grep -E "^\{NAME|COMPRESSION|TTL" | sed 's/^/   /' || true
hb "truncate '$HB_TABLE'" > /dev/null
echo "   so dong HBase truoc khi chay: $(hb_dem "$HB_TABLE")"

echo "== 2. Bat agent s1 (HTTP :$HTTP_PORT, metrics :$MON_PORT)"
bat_agent s1 "$CONF" "$WORK/log-stream" "$MON_PORT"
cho_cong "$HTTP_PORT" 90 || { echo "FAIL: HTTP source khong mo cong"; tail -30 "$WORK/log-stream/stdout.log"; exit 1; }

echo "== 3. Lan 1: phat lai $N_SRC event, nhip $RATE event/s, lo 50"
python3 replay_events.py --url "http://localhost:$HTTP_PORT" --file "$DATA/events_stream.jsonl" \
  --rate "$RATE" --batch 50 --summary "$OUT/replay_run1.json" | sed 's/^/   /'
cho_dk 120 kenh_rong || echo "   (canh bao) channel chua rong sau 120 s"
metrics

if [ "$N_RESEND" -gt 0 ]; then
  echo "== 4. Lan 2: gui lai $N_RESEND event dau, toc do toi da, lo 100 (mo phong client retry)"
  python3 replay_events.py --url "http://localhost:$HTTP_PORT" --file "$DATA/events_stream.jsonl" \
    --limit "$N_RESEND" --rate 0 --batch 100 --summary "$OUT/replay_run2.json" | sed 's/^/   /'
  cho_dk 120 kenh_rong || echo "   (canh bao) channel chua rong sau 120 s"
  echo "   metrics sau 2 lan gui:"
  metrics
fi
curl -s "http://localhost:$MON_PORT/metrics" | python3 -m json.tool > "$OUT/stream_metrics.json"

echo "== 5. Tat agent (sink HDFS dong tep, doi ten _*.tmp -> *.jsonl)"
tat_agent "$AGENT_PID"; AGENT_PID=

echo "== 6. Kiem tra HDFS"
hdfs dfs -ls "$RAW/events/ingest_date=*/" | awk '/^-/{print "   " $1, $2, $5, $8}'
read -r H_DONG H_ID H_KHOP < <(hdfs dfs -cat "$RAW/events/ingest_date=*/events.*.jsonl" | python3 -c '
import json, sys
goc = {json.loads(l)["event_id"] for l in open(sys.argv[1], encoding="utf-8") if l.strip()}
ids = [json.loads(l)["event_id"] for l in sys.stdin if l.strip()]
print(len(ids), len(set(ids)), int(set(ids) == goc))' "$DATA/events_stream.jsonl")
echo "   so dong HDFS = $H_DONG; event_id khac nhau = $H_ID; tap event_id trung tep goc: $H_KHOP"

echo "== 7. Kiem tra HBase"
H_HB=$(hb_dem "$HB_TABLE")
echo "   count '$HB_TABLE' = $H_HB"
hb "get '$HB_TABLE', 'EVT-ORD0000001'" | grep -E "timestamp=" | sed 's/^/   /'
echo "   dong goc: $(head -1 "$DATA/events_stream.jsonl")"
hb "scan '$HB_TABLE', {LIMIT => 2, COLUMNS => ['e:net_revenue']}" | grep "column=" | sed 's/^/   /'

echo "== 8. Ket qua"
KQ=0
if [ "$H_DONG" = $((N_SRC + N_RESEND)) ]; then
  echo "PASS: HDFS nhan $H_DONG dong = $N_SRC + $N_RESEND gui lai (at-least-once)"
else echo "FAIL: HDFS $H_DONG dong, mong doi $((N_SRC + N_RESEND))"; KQ=1; fi
if [ "$H_ID" = "$N_SRC" ] && [ "$H_KHOP" = 1 ]; then
  echo "PASS: khu trung theo event_id con $H_ID, dung tap goc"
else echo "FAIL: event_id HDFS ($H_ID khac nhau, khop tap goc: $H_KHOP)"; KQ=1; fi
if [ "$H_HB" = "$N_HB" ]; then
  echo "PASS: HBase $H_HB dong = so dong hop le $N_HB (gui lai khong sinh dong trung)"
else echo "FAIL: HBase $H_HB dong, mong doi $N_HB"; KQ=1; fi
exit "$KQ"
