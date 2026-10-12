#!/usr/bin/env bash
# Cau 2 - Thi nghiem chong mat du lieu: gui 1.000 su kien vao agent c0 (chua co
# sink, su kien nam trong ca FileChannel lan MemoryChannel), kill -9 agent (gia
# lap mat dien), khoi dong lai bang agent c1 (co sink), dem so su kien moi
# channel giao duoc xuong HDFS. Moi thu nam trong thu muc tam, xoa khi xong.
#   bash cau02_flume/crash_demo.sh        -> output/crash_demo.txt
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source=lib.sh disable=SC1091
. ./lib.sh

N=${N:-1000}
PORT=41497
OUT=${OUT_DIR:-output}
mkdir -p "$OUT"
TMP=$(mktemp -d /tmp/cau02_crash.XXXXXX)
HD=/tmp/cau02_crash_$(basename "$TMP" | tr -cd 'A-Za-z0-9')
sed -e "s#hdfs://masternode:9000/tmp/cau02_crash#hdfs://masternode:9000$HD#g" \
    -e "s#= /tmp/cau02_crash#= $TMP#g" conf/crash-demo.conf > "$TMP/crash.conf"

AGENT_PID=
# shellcheck disable=SC2329
don_dep() { tat_agent "$AGENT_PID"; hdfs dfs -rm -r -f -skipTrash "$HD" > /dev/null 2>&1 || true; rm -rf "$TMP"; }
trap don_dep EXIT
exec > >(tee "$OUT/crash_demo.txt") 2>&1

echo "# Cau 2 - thi nghiem sap agent ($(date '+%F %T %z')); conf: conf/crash-demo.conf"
echo "== 1. Bat agent c0 (HTTP -> FileChannel + MemoryChannel, chua co sink)"
bat_agent c0 "$TMP/crash.conf" "$TMP/log0"
cho_cong "$PORT" 90 || { echo "FAIL: c0 khong mo cong"; exit 1; }
python3 replay_events.py --url "http://localhost:$PORT" --limit "$N" --rate 0 --batch 100 | sed 's/^/   /'
echo "   tep du lieu FileChannel tren dia:"
find "$TMP/fc/data" -name 'log-*' -printf '     %f %s byte\n'

echo "== 2. kill -9 agent c0 (khong kip dong channel, mat toan bo bo nho)"
kill -9 "$AGENT_PID"; wait "$AGENT_PID" 2>/dev/null || true; AGENT_PID=

echo "== 3. Khoi dong lai bang agent c1 (cung thu muc FileChannel, them 2 sink HDFS)"
bat_agent c1 "$TMP/crash.conf" "$TMP/log1"
cho_cong "$PORT" 90 || { echo "FAIL: c1 khong mo cong"; exit 1; }
dem() { { hdfs dfs -cat "$HD/$1/events.*" 2>/dev/null || true; } | wc -l; }
du_fc() { [ "$(dem fc)" -ge "$N" ]; }
cho_dk 120 du_fc || true
sleep 10                                        # cho sink dong tep (idleTimeout 5 s)
tat_agent "$AGENT_PID"; AGENT_PID=
grep -iE "replay" "$TMP/log1/stdout.log" | sed -E 's/^.* - /   log: /' | head -5 || true

FC=$(dem fc); MC=$(dem mc)
FCU=$({ hdfs dfs -cat "$HD/fc/events.*" 2>/dev/null || true; } | python3 -c 'import json,sys; print(len({json.loads(l)["event_id"] for l in sys.stdin if l.strip()}))')
echo "== 4. Ket qua sau khi khoi dong lai"
printf '   %-14s %8s %10s %14s\n' channel da_gui giao_lai event_id_khac
printf '   %-14s %8s %10s %14s\n' FileChannel "$N" "$FC" "$FCU"
printf '   %-14s %8s %10s %14s\n' MemoryChannel "$N" "$MC" "-"
if [ "$FCU" = "$N" ] && [ "$MC" = 0 ]; then
  echo "PASS: FileChannel giao lai du $N/$N su kien sau kill -9; MemoryChannel mat $N/$N"
else
  echo "FAIL: ket qua khac du kien (FileChannel $FCU, MemoryChannel $MC)"; exit 1
fi
