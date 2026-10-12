#!/usr/bin/env bash
# Cau 3 - Tao cac vung du lieu tren HDFS va nap ban chup chuan vao raw.
# Chay lai nhieu lan van an toan (khong ghi de neu da co).
#   bash cau03_hdfs/init_zones.sh [--force]
set -euo pipefail

SNAPSHOT=${SNAPSHOT:-2026-08-01}   # ngay sau ban ghi cuoi cung (31/07/2026)
DATA=${DATA_DIR:-/data}
FORCE=${1:-}

hdfs dfs -mkdir -p /btl/raw /btl/staging /btl/curated /btl/output

nap() {  # nap <bang> <tep>
  local dst="/btl/raw/$1/ingest_date=$SNAPSHOT"
  if hdfs dfs -test -e "$dst/$2" && [ "$FORCE" != "--force" ]; then
    echo "  da co  $dst/$2"
    return
  fi
  hdfs dfs -mkdir -p "$dst"
  hdfs dfs -put -f "$DATA/$2" "$dst/$2"
  echo "  nap    $dst/$2"
}

echo "== Nap ban chup $SNAPSHOT vao /btl/raw"
nap orders orders.csv
nap customers customers.csv
nap products products.csv
nap events events_stream.jsonl

echo "== Cay thu muc /btl"
hdfs dfs -ls -R /btl | awk '{print $1, $2, $5, $8}'
