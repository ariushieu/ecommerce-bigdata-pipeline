#!/usr/bin/env bash
# Cau 3 - Thu thap so lieu that ve cac vung /btl tren HDFS: cay thu muc, dung
# luong logic va dung luong chiem dung (x3 ban sao), fsck (block, nhan ban),
# dfsadmin -report va cau hinh lien quan. Ghi vao output/zones_report.txt.
#   bash cau03_hdfs/zones_report.sh
set -euo pipefail
cd "$(dirname "$0")"
OUT=${OUT_DIR:-output}
mkdir -p "$OUT"
exec > >(tee "$OUT/zones_report.txt") 2>&1

echo "# Cau 3 - bao cao vung du lieu HDFS   ($(date '+%F %T %z'))"

echo
echo "== 1. Cau hinh (hdfs getconf)"
for k in dfs.replication dfs.blocksize dfs.heartbeat.interval dfs.namenode.heartbeat.recheck-interval \
         dfs.namenode.replication.min dfs.namenode.name.dir dfs.datanode.data.dir \
         dfs.client.block.write.replace-datanode-on-failure.policy; do
  printf '   %-60s %s\n' "$k" "$(hdfs getconf -confKey "$k" 2>/dev/null)"
done

echo
echo "== 2. Cay thu muc /btl (thu muc toi cap partition dau tien; cap sau chi dem)"
hdfs dfs -ls -R /btl | awk '/^d/{print $8}' > /tmp/cau03_dirs.$$
awk -F/ 'NF<=5' /tmp/cau03_dirs.$$ | sed 's/^/   /'
awk -F/ 'NF>5 {n[$3"/"$4]++; if (!(($3"/"$4) in vd) || NF > sau[$3"/"$4]) {vd[$3"/"$4]=$0; sau[$3"/"$4]=NF}}
  END {for (k in n) printf "   ... /btl/%s: them %d thu muc con, vi du %s\n", k, n[k], vd[k]}' /tmp/cau03_dirs.$$ | sort
rm -f /tmp/cau03_dirs.$$

echo
echo "== 3. Dung luong theo vung: hdfs dfs -du -s (cot 1 = logic, cot 2 = chiem dung tat ca ban sao)"
hdfs dfs -du -s /btl/raw /btl/staging /btl/curated /btl/output | awk '{printf "   %14s %14s  %s\n", $1, $2, $3}'
echo "   -- raw theo bang"
hdfs dfs -du -s '/btl/raw/*' | awk '{printf "   %14s %14s  %s\n", $1, $2, $3}'
echo "   -- raw theo partition"
hdfs dfs -du '/btl/raw/*' | awk '{printf "   %14s %14s  %s\n", $1, $2, $3}'
for z in staging curated output; do
  if hdfs dfs -ls "/btl/$z" 2>/dev/null | grep -q .; then
    echo "   -- $z theo thu muc con"
    hdfs dfs -du "/btl/$z" | awk '{printf "   %14s %14s  %s\n", $1, $2, $3}'
  fi
done

echo
echo "== 4. So tep va kich thuoc tep trung binh theo vung (van de tep nho)"
for z in raw staging curated output; do
  hdfs dfs -count "/btl/$z" | awk -v z="$z" '{
    tb = ($2 > 0) ? $3 / $2 : 0
    printf "   %-8s thu_muc=%-5s tep=%-6s byte=%-12s byte/tep=%.0f (%.4f%% block 128 MiB)\n", z, $1, $2, $3, tb, 100 * tb / 134217728 }'
done

echo
echo "== 5. hdfs fsck /btl (tom tat)"
hdfs fsck /btl 2>/dev/null | awk '/Erasure Coded/{exit} 1' | grep -E "Total size|Total files|Total blocks|Minimally|Over-replicated|Under-replicated|Mis-replicated|Default replication|Average block replication|Missing blocks|Corrupt blocks|Missing replicas|Number of data-nodes|Number of racks|The filesystem under path" | sed 's/^ */   /'

echo
echo "== 6. Vi tri block cua ban chup orders.csv"
hdfs fsck /btl/raw/orders/ingest_date=2026-08-01/orders.csv -files -blocks -locations 2>/dev/null \
  | grep -E "^/btl|^0\.|len=" | sed -E 's/DatanodeInfoWithStorage\[([0-9.]+):9866,DS-[^,]*,DISK\]/\1/g; s/^/   /'

echo
echo "== 7. hdfs dfsadmin -report (tom tat)"
hdfs dfsadmin -report 2>/dev/null | grep -E "^Configured Capacity|^Present Capacity|^DFS Remaining|^DFS Used|^Live datanodes|^Dead datanodes|^Name:|^Hostname:|^Last contact|^Num of Blocks|Under replicated blocks|Missing blocks" | sed 's/^/   /'

echo
echo "== 8. YARN: NodeManager"
yarn node -list -all 2>/dev/null | sed 's/^/   /'

echo
echo "== 9. HBase luu tren HDFS (/hbase/data/btl/*); flush bang su kien cua Cau 2 truoc khi do"
if echo "list" | hbase shell -n 2>/dev/null | grep -qx "btl:order_events"; then
  echo "flush 'btl:order_events'" | hbase shell -n > /dev/null 2>&1 || true
  sleep 5
fi
hdfs dfs -du -s '/hbase/data/btl/*' 2>/dev/null | awk '{printf "   %14s %14s  %s\n", $1, $2, $3}' || echo "   (chua co bang trong namespace btl)"

echo
echo "== 10. Sao luu metadata NameNode: hdfs dfsadmin -fetchImage (tai fsimage moi nhat)"
NNB=$(mktemp -d /tmp/cau03_fsimage.XXXXXX)
hdfs dfsadmin -fetchImage "$NNB" 2>&1 | tail -1 | sed 's/^/   /'
find "$NNB" -type f -printf '   %f  %s byte\n'
rm -rf "$NNB"
