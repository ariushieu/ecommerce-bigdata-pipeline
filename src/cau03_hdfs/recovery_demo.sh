#!/usr/bin/env bash
# =============================================================================
#  Cau 3 - Demo khoi phuc khi hong mot node (chay tren MAY THAT, Git Bash):
#     bash src/cau03_hdfs/recovery_demo.sh           # demo day du (TAT datanode3!)
#     bash src/cau03_hdfs/recovery_demo.sh --check   # chi chuan bi + in trang thai, khong tat node
#
#  Cac buoc:
#   1. Tao 2 tep demo trong /tmp/cau03_recovery:
#        orders_rep3.csv      : orders.csv, replication 3 (nhu vung raw)
#        orders_x4_rep2.csv   : 4 lan orders.csv, block 1 MiB, replication 2
#                               (~9 block) -> co cho trong de NameNode nhan ban lai
#   2. docker stop datanode3  (entrypoint tat RegionServer, NodeManager, DataNode)
#   3. Doc lai tep ngay lap tuc; cho NameNode danh dau dead (~2,5 phut);
#      fsck: block thieu ban sao; cho tep rep2 duoc nhan ban lai sang node con song
#   4. docker start datanode3 + bat lai daemon; cho DataNode quay lai,
#      fsck: ban sao du lai / ban sao thua bi xoa; HDFS HEALTHY
#   5. Xoa tep demo. Toan bo log: src/cau03_hdfs/output/recovery_demo.log
#
#  CANH BAO: cum dung chung - bao nhom truoc khi chay (job dang chay tren
#  datanode3 se bi chay lai, HBase chuyen region). Khong dung "docker kill".
# =============================================================================
set -euo pipefail
export MSYS_NO_PATHCONV=1          # Git Bash: khong doi /tmp, /data thanh duong dan Windows
cd "$(dirname "$0")"

NODE=${NODE:-datanode3}
DEMO=/tmp/cau03_recovery
CHECK=0; [ "${1:-}" = "--check" ] && CHECK=1
mkdir -p output
LOG=output/recovery_demo.log; [ "$CHECK" = 1 ] && LOG=output/recovery_check.log
exec > >(tee "$LOG") 2>&1

m()  { docker exec masternode su - hadoop -c "$1"; }        # lenh tren masternode
ip_ten() { sed -E 's/DatanodeInfoWithStorage\[([0-9.]+):9866,DS-[^]]*\]/\1/g;
  s/172\.28\.1\.2/datanode1/g; s/172\.28\.1\.3/datanode2/g; s/172\.28\.1\.4/datanode3/g'; }
T0=$(date +%s)
moc() { echo; echo "== [$(date +%T) | +$(( $(date +%s) - T0 )) s] $*"; }

khoi() {  # tom tat suc khoe HDFS
  m "hdfs dfsadmin -report 2>/dev/null | grep -E '^Live datanodes|^Dead datanodes|Under replicated blocks|Missing blocks:'" | sed 's/^/   /'
}
fsck_tom_tat() {  # fsck_tom_tat <duong dan>
  m "hdfs fsck $1 2>/dev/null | grep -E 'Total blocks|Under-replicated|Over-replicated|Missing blocks|Corrupt blocks|Missing replicas|Average block replication|under path'" | sed 's/^ */   /'
}
vi_tri() {  # vi_tri <tep>: block -> cac node giu ban sao
  m "hdfs fsck $1 -files -blocks -locations 2>/dev/null | grep -E 'len='" | ip_ten \
    | sed -E 's/^([0-9]+)\. [^ ]+ len=([0-9]+) Live_repl=([0-9]+)/   block \1  len=\2  Live_repl=\3/'
}
bo_tren_node() {  # so block cua tep co ban sao tren $NODE
  vi_tri "$1" | grep -c "$NODE" || true
}
cho() {  # cho <giay toi da> <buoc> <mo ta> <lenh kiem tra...>
  local max=$1 buoc=$2 mt=$3 t=0; shift 3
  until "$@"; do
    t=$((t + buoc))
    if [ "$t" -gt "$max" ]; then echo "   !! het ${max} s ma chua: $mt"; return 1; fi
    sleep "$buoc"
  done
  echo "   -> $mt (sau ~$t s cho)"
}

moc "0. Trang thai ban dau"
docker ps --format '   {{.Names}}\t{{.Status}}' | grep -E 'masternode|datanode'
khoi

moc "1. Tao tep demo trong $DEMO"
m "hdfs dfs -rm -r -f -skipTrash $DEMO >/dev/null 2>&1; hdfs dfs -mkdir -p $DEMO
   hdfs dfs -put /data/orders.csv $DEMO/orders_rep3.csv
   cat /data/orders.csv /data/orders.csv /data/orders.csv /data/orders.csv \
     | hdfs dfs -D dfs.blocksize=1048576 -D dfs.replication=2 -put - $DEMO/orders_x4_rep2.csv
   hdfs dfs -ls $DEMO" | sed 's/^/   /'
MD5_GOC=$(m "cat /data/orders.csv /data/orders.csv /data/orders.csv /data/orders.csv | md5sum | cut -c1-32")
MD5_3=$(m "md5sum < /data/orders.csv | cut -c1-32")
echo "   md5 mong doi: rep2=$MD5_GOC  rep3=$MD5_3"
echo "   -- vi tri block orders_rep3.csv"; vi_tri $DEMO/orders_rep3.csv
echo "   -- vi tri block orders_x4_rep2.csv"; vi_tri $DEMO/orders_x4_rep2.csv
echo "   so block cua tep rep2 co ban sao tren $NODE: $(bo_tren_node $DEMO/orders_x4_rep2.csv)"

if [ "$CHECK" = 1 ]; then
  moc "--check: khong tat node. Don tep demo va thoat"
  m "hdfs dfs -rm -r -f -skipTrash $DEMO" | sed 's/^/   /'
  exit 0
fi

moc "2. docker stop $NODE (gia lap hong node; entrypoint tat RegionServer, NodeManager, DataNode)"
T_STOP=$(date +%s)
docker stop "$NODE" | sed 's/^/   da dung: /'

moc "3a. Doc lai tep ngay sau khi mat node (NameNode chua biet node da chet)"
r2=$(m "hdfs dfs -cat $DEMO/orders_x4_rep2.csv 2>/dev/null | md5sum | cut -c1-32")
r3=$(m "hdfs dfs -cat $DEMO/orders_rep3.csv 2>/dev/null | md5sum | cut -c1-32")
echo "   rep2: $r2 $([ "$r2" = "$MD5_GOC" ] && echo DOC_DUOC_DUNG || echo SAI)"
echo "   rep3: $r3 $([ "$r3" = "$MD5_3" ] && echo DOC_DUOC_DUNG || echo SAI)"
khoi

moc "3b. Cho NameNode danh dau $NODE la dead (2 x recheck 60 s + 10 x heartbeat 3 s = 150 s)"
la_dead() { m "hdfs dfsadmin -report -dead 2>/dev/null" | grep "Dead datanodes (1)" > /dev/null; }
cho 420 10 "NameNode danh dau 1 DataNode dead (dfsadmin)" la_dead || true
# dfsadmin bao dead truoc khi HeartbeatManager go block cua node khoi blocksMap (removeDeadDatanode,
# chay theo chu ky recheck). Cho toi khi fsck thay tep rep3 thieu ban sao thi moi chac node da bi loai.
da_go_block() { m "hdfs fsck $DEMO/orders_rep3.csv 2>/dev/null" | grep -E "Under-replicated blocks:[[:space:]]+[1-9]" > /dev/null; }
cho 300 5 "NameNode go block cua $NODE (tep rep3 thieu ban sao)" da_go_block || true
T_DEAD=$(date +%s)
khoi
echo "   -- fsck /btl (tep rep3 chi con 2 ban sao, KHONG co node thu 3 de nhan ban lai)"
fsck_tom_tat /btl
echo "   -- fsck $DEMO"
fsck_tom_tat $DEMO

moc "3c. Cho NameNode nhan ban lai cac block cua tep rep2 sang node con song"
rep2_du() { m "hdfs fsck $DEMO/orders_x4_rep2.csv 2>/dev/null" | grep -E "Under-replicated blocks:[[:space:]]+0 " > /dev/null && [ "$(bo_tren_node $DEMO/orders_x4_rep2.csv)" = 0 ]; }
cho 300 10 "tep rep2 du 2 ban sao tren datanode1 + datanode2" rep2_du || true
T_REREP=$(date +%s)
vi_tri $DEMO/orders_x4_rep2.csv
r2=$(m "hdfs dfs -cat $DEMO/orders_x4_rep2.csv 2>/dev/null | md5sum | cut -c1-32")
echo "   doc lai rep2: $r2 $([ "$r2" = "$MD5_GOC" ] && echo DOC_DUOC_DUNG || echo SAI)"
echo "   -- YARN (NodeManager tat gon thi ResourceManager ghi SHUTDOWN ngay; hong dot ngot thi LOST sau 10 phut)"
m "yarn node -list -all 2>/dev/null" | sed 's/^/   /'
echo "   -- HBase (region cua RegionServer bi tat duoc HMaster gan sang server khac)"
m "echo \"status 'simple'\" | hbase shell -n 2>/dev/null | grep -E 'live servers|dead servers|^ +datanode|aggregate load'" | sed 's/^/   /' || true

moc "4. docker start $NODE + bat lai DataNode, NodeManager, RegionServer"
T_START=$(date +%s)
docker start "$NODE" | sed 's/^/   da bat: /'
sleep 5
docker exec "$NODE" su - hadoop -c 'hdfs --daemon start datanode; yarn --daemon start nodemanager; hbase-daemon.sh start regionserver >/dev/null; jps' | sed 's/^/   /'
la_live3() { m "hdfs dfsadmin -report -live 2>/dev/null" | grep "Live datanodes (3)" > /dev/null; }
cho 300 5 "DataNode quay lai (Live datanodes 3)" la_live3 || true
T_BACK=$(date +%s)
het_thieu() { for p in /btl $DEMO; do m "hdfs fsck $p 2>/dev/null" | grep -E "Under-replicated blocks:[[:space:]]+0 " > /dev/null || return 1; done; }
het_thua() { m "hdfs fsck $DEMO 2>/dev/null" | grep -E "Over-replicated blocks:[[:space:]]+0 " > /dev/null; }
cho 300 10 "khong con block thieu ban sao trong /btl va tep demo" het_thieu || true
cho 300 10 "ban sao thua cua tep rep2 da bi xoa" het_thua || true
T_OK=$(date +%s)
khoi
fsck_tom_tat /btl
echo "   -- vi tri block orders_x4_rep2.csv sau khi node quay lai"; vi_tri $DEMO/orders_x4_rep2.csv
m "yarn node -list -all 2>/dev/null" | sed 's/^/   /'
m "echo \"status 'simple'\" | hbase shell -n 2>/dev/null | grep -E 'live servers|dead servers'" | sed 's/^/   /' || true

moc "5. Don tep demo"
m "hdfs dfs -rm -r -f -skipTrash $DEMO" | sed 's/^/   /'

echo
echo "== Moc thoi gian (giay, tinh tu luc docker stop)"
echo "   NameNode loai node + go block: $((T_DEAD - T_STOP))"
echo "   tep rep2 nhan ban lai xong   : $((T_REREP - T_STOP))"
echo "   node bat lai (docker start)  : $((T_START - T_STOP))"
echo "   DataNode duoc tinh live lai  : $((T_BACK - T_STOP))"
echo "   HDFS het thieu/thua ban sao  : $((T_OK - T_STOP))"
