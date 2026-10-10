#!/bin/bash
# In trang thai cac tien trinh tren 4 may + dia chi Web UI. Chay tren masternode.
if [ "$(id -un)" != "hadoop" ]; then exec su - hadoop -c "$0 $*"; fi
. /etc/profile.d/btl-env.sh

JPS=$JAVA_HOME/bin/jps
echo
echo "======================== TRANG THAI CUM ========================"
echo "masternode:"
$JPS | grep -v Jps | sort -k2 | sed 's/^/   /'
for h in datanode1 datanode2 datanode3; do
  echo "$h:"
  ssh -o BatchMode=yes -o ConnectTimeout=5 "$h" "$JPS" 2>/dev/null | grep -v Jps | sort -k2 | sed 's/^/   /'
done
echo
echo "HDFS: $(hdfs dfsadmin -report 2>/dev/null | grep -m1 'Live datanodes')"
echo "Yarn: $(yarn node -list 2>/dev/null | grep -c RUNNING) NodeManager RUNNING"
echo
echo "  HDFS NameNode      http://localhost:9870"
echo "  Yarn RM            http://localhost:8088"
echo "  MR JobHistory      http://localhost:19888"
echo "  Spark History      http://localhost:18080"
echo "  HBase Master       http://localhost:16010"
echo "  RStudio            http://localhost:8787"
echo "================================================================"
