#!/usr/bin/env bash
# Cau 2 - Ham dung chung cho run_batch.sh, run_stream.sh, test.sh (source file nay).
# shellcheck disable=SC2034

# Tham so (ghi de bang bien moi truong; test.sh dung gia tri rieng de khong
# dung vao du lieu demo)
WORK=${FLUME_WORK:-/home/hadoop/flume-data/cau02}   # spool + FileChannel (o cuc bo masternode)
RAW=${RAW_ROOT:-/btl/raw}                            # goc vung raw tren HDFS
HTTP_PORT=${HTTP_PORT:-41414}                        # cong HTTP source (da mo ra may that)
HB_TABLE=${HB_TABLE:-btl:order_events}               # bang HBase nhan su kien
MON_PORT=${MON_PORT:-34545}                          # cong JSON metrics cua agent

# sinh_conf <conf goc> <conf ra>: thay cac gia tri mac dinh trong conf goc
# bang tham so o tren (mac dinh thi conf ra trung conf goc)
sinh_conf() {
  sed -e "s#/home/hadoop/flume-data/cau02#$WORK#g" \
      -e "s#hdfs://masternode:9000/btl/raw#hdfs://masternode:9000$RAW#g" \
      -e "s#^\(s1.sources.httpSrc.port\) = 41414#\1 = $HTTP_PORT#" \
      -e "s#^\(s1.sinks.hbaseEvents.table\) = btl:order_events#\1 = $HB_TABLE#" \
      "$1" > "$2"
}

# bat_agent <ten agent> <file conf> <thu muc log> [cong monitoring]
#   -> chay flume-ng nen, dat bien AGENT_PID; log cua agent: <thu muc log>/stdout.log
#      (cd vao <thu muc log> phong khi log4j2 ghi flume.log vao thu muc hien hanh).
bat_agent() {
  local ten=$1 conf=$2 logdir=$3 mport=${4:-}
  local mon=()
  [ -n "$mport" ] && mon=(-Dflume.monitoring.type=http "-Dflume.monitoring.port=$mport")
  mkdir -p "$logdir"
  ( cd "$logdir" && exec flume-ng agent -n "$ten" -c "$FLUME_HOME/conf" -f "$conf" "${mon[@]}" \
      > "$logdir/stdout.log" 2>&1 ) &
  AGENT_PID=$!
}

# tat_agent <pid>: SIGTERM -> Flume dung cac thanh phan, sink HDFS dong/doi ten tep
tat_agent() {
  local pid=$1 i
  [ -z "$pid" ] && return 0
  kill "$pid" 2>/dev/null || return 0
  for i in $(seq 1 60); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
  done
  kill -9 "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}

# cho_cong <cong> <giay>: doi den khi agent mo cong TCP
cho_cong() {
  local port=$1 max=$2 i
  for i in $(seq 1 "$max"); do
    nc -z localhost "$port" 2>/dev/null && return 0
    sleep 1
  done
  return 1
}

# cho_dk <giay> <lenh...>: lap lai lenh moi 2 s den khi thanh cong
cho_dk() {
  local max=$1 i; shift
  for i in $(seq 1 $((max / 2))); do
    "$@" && return 0
    sleep 2
  done
  return 1
}

# hb <lenh hbase shell>: chay non-interactive, in ra stdout
hb() {
  echo "$1" | hbase shell -n 2>&1
}

# hb_dem <bang>: so dong cua bang HBase
hb_dem() {
  hb "count '$1', INTERVAL => 100000, CACHE => 1000" | grep -oE '^[0-9]+ row\(s\)' | tail -1 | grep -oE '^[0-9]+'
}

# hb_tao_bang <bang> : tao namespace btl (neu thieu) va bang su kien
#   cf 'e': 1 version (rowkey idempotent, ghi lai = ghi de), nen SNAPPY,
#   TTL 180 ngay (lop toc do; lich su day du nam o HDFS)
hb_tao_bang() {
  local t=$1 ns=${1%%:*}
  # list_namespace tra ve nil trong shell -> kiem tra bang grep
  hb "list_namespace" | grep -qx "$ns" || hb "create_namespace '$ns'" > /dev/null
  hb "if !list.include?('$t') then create '$t', {NAME => 'e', VERSIONS => 1, COMPRESSION => 'SNAPPY', TTL => 15552000, BLOOMFILTER => 'ROW'} end
describe '$t'"
}

# hb_xoa_bang <bang>
hb_xoa_bang() {
  hb "if list.include?('$1') then (disable '$1' if is_enabled('$1')); drop '$1' end" > /dev/null
}
