#!/bin/bash
# Dung HBase, Spark History, JobHistory, Yarn, HDFS (dung truoc khi tat may /
# docker compose stop de du lieu HDFS va HBase duoc ghi xuong dia gon gang).
if [ "$(id -un)" != "hadoop" ]; then exec su - hadoop -c "$0 $*"; fi
. /etc/profile.d/btl-env.sh

# HMaster dang ket thi stop-hbase.sh co the treo -> gioi han 90 giay
$JAVA_HOME/bin/jps | grep -qwE "HMaster|HQuorumPeer" && timeout 90 stop-hbase.sh
stop-history-server.sh            2>/dev/null || true
mapred --daemon stop historyserver 2>/dev/null || true
stop-yarn.sh                      || true
stop-dfs.sh                       || true
echo "==> Da dung cum."
