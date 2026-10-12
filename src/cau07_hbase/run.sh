#!/usr/bin/env bash
# Cau 7 - tao bang btl:customer_orders, nap 14.408 don sach, chay demo Client API va hbase
# shell, sao luu (snapshot + ExportSnapshot) va kiem tra quyen. Ket qua ghi vao output/*.txt.
#   bash cau07_hbase/run.sh
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p output

SNAPSHOT=${SNAPSHOT:-2026-08-01}
CSV=/btl/raw/orders/ingest_date=$SNAPSHOT/orders.csv
BACKUP=/btl/backup/hbase
BUILD=$(mktemp -d)
trap 'rm -rf "$BUILD"' EXIT

bash ../cau03_hdfs/init_zones.sh > /dev/null
CP=$(hbase classpath)
javac -nowarn -cp "$CP" -d "$BUILD" CustomerOrders.java
co() {  # loi Java -> in 20 dong cuoi cua stderr roi dung
  java -cp "$BUILD:$CP" CustomerOrders "$@" 2>"$BUILD/java.err" || { grep -v SLF4J "$BUILD/java.err" | tail -20 >&2; return 1; }
}
hb() { hbase shell -n "$@" 2>&1 | grep -vE "^(SLF4J|[0-9]{4}-[0-9]{2}-[0-9]{2} .*(WARN|INFO))"; }

echo "== 1. create + load + dem dong theo region"
{
  echo "\$ java CustomerOrders create --recreate"
  co create --recreate
  echo "\$ hdfs dfs -cat $CSV | java CustomerOrders load -"
  hdfs dfs -cat "$CSV" | co load -
  echo "\$ java CustomerOrders count"
  co count
} | tee output/load.txt

echo "== 2. demo Java Client API"
KR=$(co latest C00941 20 | awk '$2 == "ORD0013507" {print $1}')
{
  echo "\$ java CustomerOrders latest C00941 5      # prefix scan, moi nhat truoc"
  co latest C00941 5
  echo "\$ java CustomerOrders get $KR"
  co get "$KR"
  echo "\$ java CustomerOrders history $KR       # 3 phien ban d:status"
  co history "$KR"
  TS=1759993200000   # 2025-10-09T14:00:00+07:00: thoi diem CSKH goi lai khach (gia dinh de minh hoa)
  echo "\$ java CustomerOrders status $KR CS_CONTACTED $TS   # them phien ban thu 4"
  co status "$KR" CS_CONTACTED "$TS"
  co history "$KR"
  echo "\$ java CustomerOrders delete $KR d:status $TS   # xoa dung phien ban do"
  co delete "$KR" d:status "$TS"
  co history "$KR"
  # dong demo rieng (khong dung vao don that): put -> get -> xoa ca dong -> get rong
  KD="C01200#0000000000000000000"
  echo "\$ java CustomerOrders status $KD TEST ; get ; delete (ca dong) ; get"
  co status "$KD" TEST "$TS"
  co get "$KD"
  co delete "$KD"
  co get "$KD"
} | tee output/client_api_demo.txt

echo "== 3. hbase shell"
hb shell_demo.rb | tee output/shell_demo.txt

echo "== 4. quyen truy cap + ExportSnapshot"
{
  echo "\$ HADOOP_USER_NAME=analyst hbase shell   # sau khi grant 'analyst', 'R'"
  printf "%s\n" "scan 'btl:customer_orders', {ROWPREFIXFILTER => 'C00941#', COLUMNS => ['o:order_id'], LIMIT => 2}" \
    | HADOOP_USER_NAME=analyst hb | grep -E "column=|row\(s\)|ERROR|Denied" || true
  printf "%s\n" "put 'btl:customer_orders', 'C00941#0', 'o:order_id', 'HACK'" \
    | HADOOP_USER_NAME=analyst hb | grep -E "ERROR|Denied|Insufficient" | head -3 || true
  echo "\$ hbase shell: revoke 'analyst', 'btl:customer_orders'"
  printf "%s\n" "revoke 'analyst', 'btl:customer_orders'" "user_permission 'btl:customer_orders'" \
    | hb | grep -vE "^(hbase:|Took)" || true
  echo "\$ HADOOP_USER_NAME=analyst hbase shell   # sau khi revoke"
  printf "%s\n" "scan 'btl:customer_orders', {LIMIT => 1}" \
    | HADOOP_USER_NAME=analyst hb | grep -E "column=|row\(s\)|ERROR|Denied|Insufficient" | head -3 || true

  echo "\$ hbase org.apache.hadoop.hbase.snapshot.ExportSnapshot -snapshot customer_orders_snap -copy-to hdfs://masternode:9000$BACKUP -mappers 2 -overwrite"
  hdfs dfs -rm -r -f -skipTrash "$BACKUP" > /dev/null 2>&1 || true   # ban sao luu cu cua chinh Cau 7
  if hbase org.apache.hadoop.hbase.snapshot.ExportSnapshot -snapshot customer_orders_snap \
       -copy-to "hdfs://masternode:9000$BACKUP" -mappers 2 -overwrite > "$BUILD/export.log" 2>&1; then
    echo "ExportSnapshot: OK"
  else
    tail -20 "$BUILD/export.log"
    echo "ExportSnapshot: LOI"
  fi
  echo "\$ hdfs dfs -du -s $BACKUP/.hbase-snapshot $BACKUP/archive"
  hdfs dfs -du -s "$BACKUP/.hbase-snapshot" "$BACKUP/archive"
} | tee output/acl_backup.txt

echo "== 5. dung luong: SNAPPY + FAST_DIFF so voi khong nen (2 bang tam, cung 14.408 dong, 1 lan flush)"
{
  echo "byte_1_ban_sao  byte_x3_ban_sao  thu_muc"
  for kieu in snappy plain; do
    t="btl:customer_orders_size_$kieu"
    opt=-Dplain=false
    [ "$kieu" = plain ] && opt=-Dplain=true
    java "-Dtable=$t" "$opt" -cp "$BUILD:$CP" CustomerOrders create --recreate > /dev/null 2>&1
    hdfs dfs -cat "$CSV" | java "-Dtable=$t" -cp "$BUILD:$CP" CustomerOrders load - > /dev/null 2>&1
    java "-Dtable=$t" -cp "$BUILD:$CP" CustomerOrders flush > /dev/null 2>&1
    sleep 3
    hdfs dfs -du -s "/hbase/data/btl/${t#btl:}"
    java "-Dtable=$t" -cp "$BUILD:$CP" CustomerOrders drop > /dev/null 2>&1
  done
  hdfs dfs -du -s "/btl/raw/orders/ingest_date=$SNAPSHOT/orders.csv"
} | tee output/compression.txt
