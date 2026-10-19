#!/usr/bin/env bash
# Demo Cau 3 - hong mot DataNode va HDFS tu khoi phuc, chay hoan toan trong ssh may1:
#   bash ~/src/demo/cau03_hong_node.sh          (khoang 3 phut, trong luc do khong chay job khac)
# 1. Tao 2 tep demo: orders_rep3.csv (nhan ban 3) va orders_x4_rep2.csv (9 block, nhan ban 2)
# 2. ssh datanode3: tat tien trinh DataNode (gia lap node hong)
# 3. Doc lai tep ngay; cho NameNode danh dau node chet (~150 s); cho tep rep2 duoc nhan ban lai
# 4. ssh datanode3: bat lai DataNode; cho HDFS het thieu/thua ban sao
# 5. Xoa tep demo. Log: ~/src/cau03_hdfs/output/hong_node.log
# shellcheck source=lib.sh disable=SC1091
. "$(dirname "$0")/lib.sh"
cd "$SRC/cau03_hdfs" || exit 1
set -o pipefail

NODE=${NODE:-datanode3}
DEMO=/tmp/cau03_hong_node
HDFS_BIN=$HADOOP_HOME/bin/hdfs
mkdir -p output
exec > >(tee output/hong_node.log) 2>&1

T0=$(date +%s)
moc() { printf '\n%s== [%s | +%s s] %s%s\n' "$C_BUOC" "$(date +%T)" "$(( $(date +%s) - T0 ))" "$*" "$C_HET"; }
ip_ten() { sed -E 's/DatanodeInfoWithStorage\[([0-9.]+):9866,DS-[^]]*\]/\1/g;
  s/172\.28\.1\.2/datanode1/g; s/172\.28\.1\.3/datanode2/g; s/172\.28\.1\.4/datanode3/g'; }
# thieu: so block thieu ban sao trong /btl va tep demo. Khong dem toan HDFS: WAL cua HBase
# dang ghi do cung mat 1 ban sao khi tat node, nhung chi duoc nhan ban bu khi WAL dong (~1 gio).
thieu() {
  local n=0 p x
  for p in /btl $DEMO; do
    x=$(hdfs fsck "$p" 2>/dev/null | sed -n 's/^[[:space:]]*Under-replicated blocks:[[:space:]]*\([0-9]*\).*/\1/p' | head -1)
    n=$(( n + ${x:-0} ))
  done
  echo "$n"
}
khoi() {
  hdfs dfsadmin -report 2>/dev/null | grep -E '^Live datanodes|^Dead datanodes' | sed 's/^/   /'
  echo "   Block thieu ban sao trong /btl va tep demo: $(thieu)"
}
vi_tri() {
  hdfs fsck "$1" -files -blocks -locations 2>/dev/null | grep -E 'len=' | ip_ten \
    | sed -E 's/^([0-9]+)\. [^ ]+ len=([0-9]+) Live_repl=([0-9]+)/   block \1  len=\2  Live_repl=\3/'
}
md5() { hdfs dfs -cat "$1" 2>/dev/null | md5sum | cut -c1-32; }
doc_lai() {
  local a b
  a=$(md5 $DEMO/orders_x4_rep2.csv); b=$(md5 $DEMO/orders_rep3.csv)
  echo "   rep2: $a $([ "$a" = "$MD5_2" ] && echo DOC_DUOC_DUNG || echo SAI)"
  echo "   rep3: $b $([ "$b" = "$MD5_3" ] && echo DOC_DUOC_DUNG || echo SAI)"
}
live_la() { [ "$(live)" = "$1" ]; }
live() { hdfs dfsadmin -report 2>/dev/null | sed -n 's/^Live datanodes (\([0-9]*\)).*/\1/p'; }
het_thieu() { [ "$(thieu)" = 0 ]; }
rep2_du() {  # 9 block deu du 2 ban sao va khong con ban sao nao tren node hong
  local v; v=$(vi_tri $DEMO/orders_x4_rep2.csv)
  [ "$(grep -c "Live_repl=2" <<< "$v")" -eq 9 ] && [ "$(grep -c "$NODE" <<< "$v")" -eq 0 ]
}
cho() {  # cho <giay toi da> <mo ta> <lenh kiem tra...>
  local max=$1 mt=$2 t=0; shift 2
  until "$@"; do
    t=$((t + 5))
    if [ "$t" -gt "$max" ]; then echo "   !! het ${max} s ma chua: $mt"; return 1; fi
    sleep 5
  done
  echo "   -> $mt (sau ~$t s cho)"
}

tieude "Cau 3 - Hong DataNode $NODE: HDFS van doc duoc va tu nhan ban lai"

moc "0. Trang thai ban dau"
khoi

moc "1. Tao tep demo trong $DEMO"
hdfs dfs -rm -r -f -skipTrash $DEMO > /dev/null 2>&1
hdfs dfs -mkdir -p $DEMO
hdfs dfs -put /data/orders.csv $DEMO/orders_rep3.csv
cat /data/orders.csv /data/orders.csv /data/orders.csv /data/orders.csv \
  | hdfs dfs -D dfs.blocksize=1048576 -D dfs.replication=2 -put - $DEMO/orders_x4_rep2.csv
hdfs dfs -ls $DEMO | sed 's/^/   /'
MD5_2=$(cat /data/orders.csv /data/orders.csv /data/orders.csv /data/orders.csv | md5sum | cut -c1-32)
MD5_3=$(md5sum < /data/orders.csv | cut -c1-32)
echo "   -- vi tri block orders_rep3.csv"; vi_tri $DEMO/orders_rep3.csv
echo "   -- vi tri block orders_x4_rep2.csv"; vi_tri $DEMO/orders_x4_rep2.csv

moc "2. ssh $NODE: tat DataNode (gia lap node hong)"
T_HONG=$(date +%s)
lenh "ssh $NODE '$HDFS_BIN --daemon stop datanode'"

moc "3a. Doc lai ngay (NameNode chua biet node da chet)"
doc_lai
khoi

moc "3b. Cho NameNode danh dau $NODE la dead (2 x 60 s recheck + 10 x 3 s heartbeat = 150 s)"
cho 300 "NameNode chi con 2 DataNode song" live_la 2
T_DEAD=$(date +%s)
khoi

moc "3c. Cho NameNode nhan ban lai cac block cua tep rep2 sang 2 node con song"
cho 240 "tep rep2 du 2 ban sao tren node con song" rep2_du
T_REP=$(date +%s)
vi_tri $DEMO/orders_x4_rep2.csv
doc_lai
khoi   # tep nhan ban 3 thieu 1 ban: cum chi con 2 DataNode, cho node quay lai

moc "4. ssh $NODE: bat lai DataNode"
T_BAT=$(date +%s)
lenh "ssh $NODE '$HDFS_BIN --daemon start datanode'"
cho 180 "DataNode quay lai (Live datanodes 3)" live_la 3
T_LIVE=$(date +%s)
cho 300 "HDFS het block thieu ban sao" het_thieu
T_OK=$(date +%s)
khoi
hdfs fsck /btl 2>/dev/null | grep -E 'under path' | sed 's/^/   /'

moc "5. Don tep demo"
hdfs dfs -rm -r -f -skipTrash $DEMO > /dev/null 2>&1 && echo "   da xoa $DEMO"

moc "Moc thoi gian (giay, tinh tu luc tat DataNode)"
echo "   NameNode danh dau node chet  : $(( T_DEAD - T_HONG ))"
echo "   tep rep2 nhan ban lai xong   : $(( T_REP - T_HONG ))"
echo "   bat lai DataNode             : $(( T_BAT - T_HONG ))"
echo "   DataNode duoc tinh live lai  : $(( T_LIVE - T_HONG ))"
echo "   HDFS het thieu ban sao       : $(( T_OK - T_HONG ))"

kq "Doc lai ngay sau khi tat DataNode: dung md5 ca 2 tep"
kq "NameNode danh dau $NODE chet sau $(( T_DEAD - T_HONG )) s"
kq "Tep nhan ban 2 duoc nhan ban lai sang node con song sau $(( T_REP - T_HONG )) s"
kq "Bat lai DataNode: HDFS het thieu ban sao sau $(( T_OK - T_HONG )) s, $(hdfs fsck /btl 2>/dev/null | grep -oE 'is (HEALTHY|CORRUPT)')"
web http://localhost:9870 "HDFS: Datanodes (bam F5 trong luc chay de thay $NODE chuyen Dead roi In Service)"
tong_ket
