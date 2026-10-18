#!/usr/bin/env bash
# Demo Cau 3 - Vung du lieu HDFS, nhan ban, khoi phuc (ssh may1):  bash ~/src/demo/cau03.sh
# Demo tat node that (4 phut) chay tren may that: bash src/cau03_hdfs/recovery_demo.sh
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

buoc "Ket qua demo hong datanode3 (log lan chay that): van doc duoc, NameNode tu nhan ban lai"
lenh "grep -E '^== |DOC_DUOC|Live datanodes|Under replicated|HEALTHY' output/recovery_demo.log | head -40"
lenh "sed -n '/^== Moc thoi gian/,\$p' output/recovery_demo.log"
web "HDFS http://localhost:9870 (Datanodes, Utilities > Browse the file system > /btl)"
