#!/usr/bin/env bash
# Cau 3 - Kiem thu tu dong (CI): tao vung + nap ban chup, kiem tra
#   - 4 vung raw/staging/curated/output ton tai
#   - 4 tep ban chup co dung kich thuoc tep goc, replication = 3, HDFS HEALTHY
#   - cau hinh dung nhu bao cao (replication 3, block 128 MiB, ~150 s danh dau dead)
#   - cac script con lai dung cu phap
# Khong tao them gi ngoai cac thu muc /btl ma init_zones.sh tao. ~30 s.
set -uo pipefail   # khong -e: moi kiem tra tu bao PASS/FAIL
cd "$(dirname "$0")" || exit 1

LOI=0
kq() {  # kq <0|1> <thong diep>
  if [ "$1" = 0 ]; then echo "PASS: $2"; else echo "FAIL: $2"; LOI=1; fi
}

echo "== init_zones.sh"
bash init_zones.sh > /tmp/cau03_test_init.$$ 2>&1 || { cat /tmp/cau03_test_init.$$; rm -f /tmp/cau03_test_init.$$; exit 1; }
grep -E "^  (nap|da co)" /tmp/cau03_test_init.$$ || true
rm -f /tmp/cau03_test_init.$$

echo "== Vung du lieu"
for z in raw staging curated output; do
  hdfs dfs -test -d "/btl/$z"; kq $? "/btl/$z ton tai"
done

echo "== Ban chup ingest_date=2026-08-01"
SNAP=ingest_date=2026-08-01
for p in orders/orders.csv customers/customers.csv products/products.csv events/events_stream.jsonl; do
  bang=${p%%/*}; tep=${p##*/}
  f="/btl/raw/$bang/$SNAP/$tep"
  read -r sz rep < <(hdfs dfs -stat '%b %r' "$f")
  goc=$(stat -c %s "${DATA_DIR:-/data}/$tep")
  r=0; [ "$sz" = "$goc" ] && [ "$rep" = 3 ] || r=1; kq "$r" "$f: $sz byte (goc $goc), replication=$rep"
done

FSCK=$(hdfs fsck "/btl/raw" 2>/dev/null)
echo "$FSCK" | grep -q "is HEALTHY"; kq $? "fsck /btl/raw HEALTHY"
echo "$FSCK" | grep -qE "Missing blocks:[[:space:]]+0"; kq $? "fsck /btl/raw: 0 block mat"
echo "$FSCK" | grep -qE "Default replication factor:[[:space:]]+3"; kq $? "fsck: he so nhan ban mac dinh 3"

echo "== Cau hinh lien quan khoi phuc"
r=0; [ "$(hdfs getconf -confKey dfs.replication)" = 3 ] || r=1; kq "$r" "dfs.replication = 3"
r=0; [ "$(hdfs getconf -confKey dfs.blocksize)" = 134217728 ] || r=1; kq "$r" "dfs.blocksize = 128 MiB"
RC=$(hdfs getconf -confKey dfs.namenode.heartbeat.recheck-interval)
HB=$(hdfs getconf -confKey dfs.heartbeat.interval | tr -d 's')
DEAD=$(( 2 * RC / 1000 + 10 * HB ))
r=0; [ "$DEAD" = 150 ] || r=1; kq "$r" "thoi gian danh dau DataNode dead = 2 x $RC ms + 10 x $HB s = $DEAD s"
LIVE=$(hdfs dfsadmin -report -live 2>/dev/null | grep -oE "Live datanodes \([0-9]+\)" | grep -oE "[0-9]+")
r=0; [ "${LIVE:-0}" -ge 3 ] || r=1; kq "$r" "so DataNode song = ${LIVE:-0} (>= he so nhan ban 3)"

echo "== Cu phap script"
bash -n recovery_demo.sh; kq $? "recovery_demo.sh dung cu phap bash"
python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' parquet_probe.py; kq $? "parquet_probe.py dung cu phap Python"

exit "$LOI"
