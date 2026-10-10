#!/bin/bash
# =============================================================================
#  CUU HO HBase: dung khi HMaster ket "Master is initializing" / bang ket o
#  trang thai transition (thuong do container bi tat dot ngot).
#
#  !!! XOA TOAN BO BANG HBase (thu muc /hbase tren HDFS + du lieu ZooKeeper).
#      Du lieu HDFS khac (raw/staging/curated/...) KHONG bi anh huong.
#      Sau khi reset, chay lai script tao/nap bang cua Cau 7.
#
#  Chay tren masternode:   hbase-reset.sh        (hoi xac nhan)
#                          hbase-reset.sh --yes  (khong hoi)
# =============================================================================
if [ "$(id -un)" != "hadoop" ]; then exec su - hadoop -c "$0 $*"; fi
. /etc/profile.d/btl-env.sh

if [ "${1:-}" != "--yes" ]; then
  read -r -p "Xoa TOAN BO bang HBase va khoi dong lai HBase? Go 'yes' de tiep tuc: " ans
  [ "$ans" = yes ] || { echo "Huy."; exit 1; }
fi

WORKERS="datanode1 datanode2 datanode3"

echo "==> Dung HBase (toi da 60 giay)"
timeout 60 stop-hbase.sh >/dev/null 2>&1

echo "==> Giet cac tien trinh HBase con sot"
jps | awk '/HMaster|HQuorumPeer/ {print $1}' | xargs -r kill -9 2>/dev/null
for h in $WORKERS; do
  ssh "$h" 'kill -9 $(jps | awk "/HRegionServer/ {print \$1}") 2>/dev/null; rm -f /tmp/hbase-*.pid'
done
rm -f /tmp/hbase-*.pid

echo "==> Xoa /hbase tren HDFS va du lieu ZooKeeper"
hdfs dfs -rm -r -f -skipTrash /hbase
rm -rf /home/hadoop/hdfs/zookeeper/*

echo "==> Khoi dong lai HBase"
start-hbase.sh 2>&1 | sed 's/, logging to .*//'

echo "==> Cho HMaster khoi tao xong"
for _ in $(seq 1 30); do
  echo "status" | hbase shell -n 2>/dev/null | grep -q "active master" && break
  sleep 3
done
echo "status" | hbase shell -n 2>/dev/null | grep -E "master|servers"
