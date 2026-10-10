#!/bin/bash
# =============================================================================
#  Kiem tra nhanh moi cong cu trong cum deu chay duoc (khong phai bai lam).
#  Chay tren masternode sau khi start-cluster.sh:   smoke-test.sh
#  Dung du lieu that o /data (thu muc De_01_thuong_mai_dien_tu, chi doc).
#  Moi thu tao ra nam trong /tmp/smoke (HDFS) va bang 'smoke_*' (HBase), xoa
#  sach khi xong.
# =============================================================================
if [ "$(id -un)" != "hadoop" ]; then exec su - hadoop -c "$0 $*"; fi
. /etc/profile.d/btl-env.sh

W=/tmp/smoke-local; S=/tmp/smoke
rm -rf $W; mkdir -p $W; cd $W || exit 1
PASS=0; FAIL=0; KQ=()
ok()   { PASS=$((PASS+1)); KQ+=("  PASS  $1"); echo "    -> PASS"; }
fail() { FAIL=$((FAIL+1)); KQ+=("  FAIL  $1  (log: $W/$2)"); echo "    -> FAIL, xem $W/$2"; }
buoc() { echo; echo "==> $1"; }

hdfs dfs -rm -r -f -skipTrash $S >/dev/null 2>&1
hdfs dfs -mkdir -p $S

# Bang smoke_* sot lai tu lan chay truoc bi loi ("hbase shell -n" dung ngay o
# lenh loi dau tien nen co the chua kip drop) -> xoa truoc cho chac
don_hbase() {
  echo "['smoke_orders', 'smoke_events'].each { |t| if list.include?(t) then (disable t if is_enabled(t)); drop t end }" \
    | hbase shell -n > /dev/null 2>&1
}
don_hbase

# --- 1. HDFS -----------------------------------------------------------------
buoc "1. HDFS: put products.csv, kiem tra nhan ban 3"
hdfs dfs -put /data/products.csv $S/products.csv > hdfs.log 2>&1
R=$(hdfs dfs -stat %r $S/products.csv 2>>hdfs.log)
echo "    replication = $R"
[ "$R" = 3 ] && ok "HDFS (replication=3)" || fail "HDFS" hdfs.log

# --- 2. MapReduce Java -------------------------------------------------------
buoc "2. MapReduce (Java, wordcount mau cua Hadoop) tren Yarn"
hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar \
  wordcount $S/products.csv $S/wc > mr.log 2>&1 \
  && hdfs dfs -test -e $S/wc/_SUCCESS && ok "MapReduce Java" || fail "MapReduce Java" mr.log

# --- 3. Hadoop Streaming + Python --------------------------------------------
buoc "3. Hadoop Streaming + Python3: dem san pham theo category"
cat > mapper.py <<'EOF'
#!/usr/bin/env python3
import sys
for line in sys.stdin:
    f = line.lstrip('\ufeff').rstrip('\n').split(',')
    if f[0] != 'product_id':
        print(f"{f[1]}\t1")
EOF
cat > reducer.py <<'EOF'
#!/usr/bin/env python3
import sys
cur, n = None, 0
for line in sys.stdin:
    k, v = line.rstrip('\n').split('\t')
    if k != cur:
        if cur is not None: print(f"{cur}\t{n}")
        cur, n = k, 0
    n += int(v)
if cur is not None: print(f"{cur}\t{n}")
EOF
hadoop jar $HADOOP_HOME/share/hadoop/tools/lib/hadoop-streaming-*.jar \
  -files mapper.py,reducer.py -mapper "python3 mapper.py" -reducer "python3 reducer.py" \
  -input $S/products.csv -output $S/streaming > streaming.log 2>&1
hdfs dfs -cat "$S/streaming/part-*" 2>>streaming.log | tee streaming.out | sed 's/^/    /'
[ "$(wc -l < streaming.out)" = 6 ] && ok "Hadoop Streaming Python" || fail "Hadoop Streaming Python" streaming.log

# --- 4. Spark (PySpark tren Yarn) ---------------------------------------------
buoc "4. PySpark tren Yarn: doc CSV tu HDFS, groupBy category"
cat > spark_smoke.py <<EOF
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName("smoke-test").getOrCreate()
df = spark.read.option("header", True).option("inferSchema", True).csv("$S/products.csv")
out = df.groupBy("category").count().orderBy("category")
out.show()
print("SMOKE_ROWS", out.count())
spark.stop()
EOF
spark-submit spark_smoke.py > spark.log 2>&1
grep -v "^[0-9][0-9]/" spark.log | grep -E "^\||^\+" | sed 's/^/    /'
grep -q "SMOKE_ROWS 6" spark.log && ok "Spark (PySpark + Yarn)" || fail "Spark" spark.log

# --- 5. Pig (che do mapreduce tren Yarn) ---------------------------------------
buoc "5. Pig Latin (mapreduce mode): LOAD, FILTER, GROUP, COUNT, STORE"
cat > smoke.pig <<EOF
p   = LOAD '$S/products.csv' USING PigStorage(',')
      AS (product_id:chararray, category:chararray, brand:chararray, unit_cost:double,
          list_price:double, supplier_id:chararray, rating:double, active_flag:int);
p   = FILTER p BY NOT (product_id MATCHES '.*product_id');   -- bo dong tieu de (co BOM)
g   = GROUP p BY category;
out = FOREACH g GENERATE group AS category, COUNT(p) AS n, ROUND_TO(AVG(p.list_price), 2) AS avg_price;
STORE out INTO '$S/pig' USING PigStorage(',');
EOF
pig -x mapreduce -f smoke.pig > pig.log 2>&1
hdfs dfs -cat "$S/pig/part-*" 2>>pig.log | tee pig.out | sed 's/^/    /'
[ "$(wc -l < pig.out)" = 6 ] && ok "Pig (mapreduce mode)" || fail "Pig" pig.log

# --- 6. HBase ----------------------------------------------------------------
buoc "6. HBase shell: create (SNAPPY + TTL + pre-split) / put / get / scan / drop"
cat > hbase.rb <<'EOF'
create 'smoke_orders', {NAME => 'o', COMPRESSION => 'SNAPPY', VERSIONS => 3, TTL => 31536000}, {NAME => 'c'}, {NAME => 'd'}, SPLITS => ['C004', 'C008']
put 'smoke_orders', 'C00941#9223370268000000000', 'o:net_revenue', '2703.86'
put 'smoke_orders', 'C00941#9223370268000000000', 'c:segment', 'Regular'
get 'smoke_orders', 'C00941#9223370268000000000'
scan 'smoke_orders', {LIMIT => 5}
get_splits 'smoke_orders'
disable 'smoke_orders'
drop 'smoke_orders'
exit
EOF
hbase shell -n hbase.rb > hbase.log 2>&1
grep -E "column=" hbase.log | sed 's/^/    /'
NS=$(grep -oE 'Total number of splits = [0-9]+' hbase.log | grep -oE '[0-9]+$')
echo "    so region sau pre-split = ${NS:-0} (diem chia: C004, C008)"
grep -q "value=2703.86" hbase.log && [ "${NS:-0}" = 3 ] \
  && ok "HBase (SNAPPY, TTL, 3 region)" || fail "HBase" hbase.log

# --- 7. Flume ----------------------------------------------------------------
buoc "7. Flume: netcat -> FileChannel -> HDFS sink  va  HTTP -> MemoryChannel -> HBase2 sink"
echo "create 'smoke_events', 'e'" | hbase shell -n > flume-hbase-create.log 2>&1
cat > smoke-flume.conf <<EOF
a1.sources  = nc http
a1.channels = fc mc
a1.sinks    = hdfsSink hbaseSink

a1.sources.nc.type = netcat
a1.sources.nc.bind = 0.0.0.0
a1.sources.nc.port = 44444
a1.sources.nc.channels = fc

a1.sources.http.type = http
a1.sources.http.bind = 0.0.0.0
a1.sources.http.port = 41414
a1.sources.http.channels = mc

a1.channels.fc.type = file
a1.channels.fc.checkpointDir = $W/flume/checkpoint
a1.channels.fc.dataDirs = $W/flume/data
a1.channels.mc.type = memory

a1.sinks.hdfsSink.type = hdfs
a1.sinks.hdfsSink.channel = fc
a1.sinks.hdfsSink.hdfs.path = $S/flume/%Y-%m-%d
a1.sinks.hdfsSink.hdfs.useLocalTimeStamp = true
a1.sinks.hdfsSink.hdfs.fileType = DataStream
a1.sinks.hdfsSink.hdfs.rollInterval = 5
a1.sinks.hdfsSink.hdfs.rollCount = 0
a1.sinks.hdfsSink.hdfs.rollSize = 0

a1.sinks.hbaseSink.type = hbase2
a1.sinks.hbaseSink.channel = mc
a1.sinks.hbaseSink.table = smoke_events
a1.sinks.hbaseSink.columnFamily = e
EOF
flume-ng agent -n a1 -c $FLUME_HOME/conf -f smoke-flume.conf > flume.log 2>&1 &
FPID=$!
for _ in $(seq 1 30); do nc -z localhost 44444 2>/dev/null && nc -z localhost 41414 2>/dev/null && break; sleep 2; done
head -3 /data/events_stream.jsonl | nc -q 1 localhost 44444 > /dev/null
curl -s -X POST -H 'Content-Type: application/json' \
  -d '[{"headers":{},"body":"{\"event_id\":\"EVT-SMOKE\",\"event_type\":\"order_event\"}"}]' \
  http://localhost:41414 > /dev/null
sleep 15
kill $FPID 2>/dev/null; wait $FPID 2>/dev/null
N=$(hdfs dfs -cat "$S/flume/*/*" 2>/dev/null | grep -c order_event)
echo "    HDFS nhan $N/3 su kien"
echo "scan 'smoke_events'" | hbase shell -n > flume-hbase-scan.log 2>&1
grep -q "EVT-SMOKE" flume-hbase-scan.log && H=1 || H=0
echo "    HBase nhan $H/1 su kien"
don_hbase
[ "$N" = 3 ] && ok "Flume netcat -> HDFS" || fail "Flume -> HDFS" flume.log
[ "$H" = 1 ] && ok "Flume HTTP -> HBase" || fail "Flume -> HBase" flume.log

# --- Don dep -----------------------------------------------------------------
hdfs dfs -rm -r -f -skipTrash $S >/dev/null 2>&1

echo
echo "========================= KET QUA SMOKE TEST ========================="
printf '%s\n' "${KQ[@]}"
echo "  => $PASS PASS, $FAIL FAIL"
echo "======================================================================"
[ "$FAIL" = 0 ]
