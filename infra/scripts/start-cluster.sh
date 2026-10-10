#!/bin/bash
# =============================================================================
#  Khoi dong toan bo cum BTL. Chay tren masternode:
#     start-cluster.sh            # HDFS + Yarn + JobHistory + Spark History + HBase
#     start-cluster.sh --no-hbase # bo HBase cho nhe may
#
#  Chay lai bao nhieu lan cung duoc: phan nao dang chay thi bo qua.
# =============================================================================
if [ "$(id -un)" != "hadoop" ]; then exec su - hadoop -c "$0 $*"; fi
. /etc/profile.d/btl-env.sh

WITH_HBASE=1
[ "${1:-}" = "--no-hbase" ] && WITH_HBASE=0

JPS=$JAVA_HOME/bin/jps
WORKERS="datanode1 datanode2 datanode3"

tren_master() { $JPS 2>/dev/null | grep -qw "$1"; }
tren_moi_worker() {
  for h in $WORKERS; do
    ssh -o BatchMode=yes -o ConnectTimeout=5 "$h" "$JPS" 2>/dev/null | grep -qw "$1" || return 1
  done
}
bo_dong_da_chay() { grep -v "Stop it first"; }

echo "==> Cho cac datanode san sang..."
for h in $WORKERS; do
  for _ in $(seq 1 30); do
    if nc -z "$h" 22 2>/dev/null; then echo "    $h: OK"; break; fi
    sleep 2
  done
done

# --- HDFS --------------------------------------------------------------------
if [ ! -d /home/hadoop/hdfs/namenode/current ]; then
  echo "==> Format NameNode (lan dau)"
  hdfs namenode -format -force -nonInteractive 2>&1 | tail -n 2
fi

echo "==> HDFS"
if tren_master NameNode && tren_moi_worker DataNode; then
  echo "    da chay san - bo qua"
else
  start-dfs.sh 2>&1 | bo_dong_da_chay
fi

# --- Yarn + MapReduce JobHistory --------------------------------------------
echo "==> Yarn"
if tren_master ResourceManager && tren_moi_worker NodeManager; then
  echo "    da chay san - bo qua"
else
  start-yarn.sh 2>&1 | bo_dong_da_chay
fi

echo "==> Cho HDFS ra khoi safe mode"
hdfs dfsadmin -safemode wait >/dev/null 2>&1

hdfs dfs -mkdir -p /spark-logs /spark-libs /user/hadoop /tmp/logs /mr-history 2>/dev/null
hdfs dfs -chmod -R 1777 /tmp 2>/dev/null
hdfs dfs -chmod 777 /spark-logs 2>/dev/null

echo "==> MapReduce JobHistory Server"
if tren_master JobHistoryServer; then
  echo "    da chay san - bo qua"
else
  mapred --daemon start historyserver
fi

# --- Spark --------------------------------------------------------------------
if ! hdfs dfs -test -e /spark-libs/spark-libs.jar 2>/dev/null; then
  echo "==> Dong goi jar cua Spark len HDFS (chi lam mot lan)"
  (cd "$SPARK_HOME/jars" && jar cv0f /tmp/spark-libs.jar . >/dev/null)
  hdfs dfs -put -f /tmp/spark-libs.jar /spark-libs/spark-libs.jar
  rm -f /tmp/spark-libs.jar
fi

echo "==> Spark History Server"
if tren_master HistoryServer; then
  echo "    da chay san - bo qua"
else
  start-history-server.sh >/dev/null
fi

# --- HBase (+ ZooKeeper) -----------------------------------------------------
if [ "$WITH_HBASE" = 1 ]; then
  echo "==> HBase"
  if tren_master HMaster && tren_moi_worker HRegionServer; then
    echo "    da chay san - bo qua"
  else
    start-hbase.sh 2>&1 | sed 's/, logging to .*//'
  fi
fi

# Cho cac NodeManager dang ky xong roi moi in trang thai
for _ in $(seq 1 15); do
  [ "$(yarn node -list 2>/dev/null | grep -c RUNNING)" -ge 3 ] && break
  sleep 2
done

/home/hadoop/scripts/status.sh
