#!/usr/bin/env bash
# Demo Cau 3 - Vung du lieu HDFS, nhan ban, khoi phuc (ssh may1):  bash ~/src/demo/cau03.sh
# Demo tat DataNode truc tiep (4 phut): bash ~/src/demo/cau03_hong_node.sh
# shellcheck source=lib.sh disable=SC1091
. "$(dirname "$0")/lib.sh"
cd "$SRC/cau03_hdfs" || exit 1
ORD=/btl/raw/orders/ingest_date=2026-08-01/orders.csv

tieude "Cau 3 - Luu tru phan tan tren HDFS (bao cao muc 3.2.1)"

buoc "4 vung du lieu: raw -> staging -> curated -> output"
lenh "hdfs dfs -ls -R /btl/raw /btl/staging /btl/curated /btl/output | awk '/^d/{print \$8}' | awk -F/ 'NF<=4'"

buoc "Dung luong moi vung: cot 1 = du lieu, cot 2 = chiem dung that (x3 ban sao)"
lenh 'hdfs dfs -du -s -h /btl/raw /btl/staging /btl/curated /btl/output'

buoc "Cum co 3 DataNode; moi block cua orders.csv nam tren ca 3 node"
lenh "hdfs dfsadmin -report 2>/dev/null | grep -E '^Live datanodes|^Name:'"
lenh "hdfs fsck $ORD -files -blocks -locations 2>/dev/null | grep -E 'len=|Average block replication' | sed -E 's/BP-[^:]*://; s/DatanodeInfoWithStorage\\[([0-9.]+):9866[^]]*\\]/\\1/g'"

buoc "Ket qua lan tat DataNode tren datanode3 (bash ~/src/demo/cau03_hong_node.sh): van doc duoc, tu nhan ban lai"
lenh "sed 's/\x1b\[[0-9;]*m//g; /Moc thoi gian/q' output/hong_node.log | grep -E '^== |DOC_DUOC|Live datanodes|thieu ban sao|HEALTHY|->'"
lenh "sed 's/\x1b\[[0-9;]*m//g' output/hong_node.log | grep -E ' : [0-9]+\$'"

kq "$(hdfs dfsadmin -report 2>/dev/null | grep -m1 '^Live datanodes' | tr -d ':'), nhan ban 3 lan"
while read -r a ua b ub z; do kq "$z: $a $ua du lieu, chiem $b $ub (x3)"; done \
  < <(hdfs dfs -du -s -h /btl/raw /btl/staging /btl/curated /btl/output)
while read -r d; do kq "Tat DataNode: $d"; done \
  < <(sed 's/\x1b\[[0-9;]*m//g' output/hong_node.log | grep -E ' : [0-9]+$')
web http://localhost:9870 "HDFS: Datanodes (3 node In Service); Utilities > Browse the file system > /btl"
tong_ket
