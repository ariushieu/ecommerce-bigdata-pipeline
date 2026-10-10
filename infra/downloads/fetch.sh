#!/bin/bash
# =============================================================================
#  Tai truoc cac ban cai cho cum BTL vao thu muc nay.
#  Chay lai duoc nhieu lan: file da tai xong se bo qua, file dut se tai tiep.
#     bash infra/downloads/fetch.sh
# =============================================================================
set -u
cd "$(dirname "$0")" || exit 1

HADOOP_VERSION=3.2.2
SPARK_VERSION=3.1.2
SCALA_VERSION=2.12.14
SBT_VERSION=1.9.9
PIG_VERSION=0.17.0
FLUME_VERSION=1.11.0
HBASE_VERSION=2.5.16

# Tai mot file, thu lan luot nhieu nguon (archive.apache.org rat cham nen de sau)
get() {
  local out="$1"; shift
  if [ -f "$out.done" ]; then echo "OK   $out (da co)"; return 0; fi
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    for url in "$@"; do
      echo "...  tai $out tu $url (lan $attempt)"
      if curl -fL -C - --connect-timeout 20 --retry 2 -o "$out" "$url"; then
        touch "$out.done"; echo "OK   $out ($(du -h "$out" | cut -f1))"; return 0
      fi
    done
    sleep 5
  done
  echo "FAIL $out"; return 1
}

# Toc do do ngay 04/10/2026: dlcdn ~6-8 MB/s (khong co Pig), ustc/huaweicloud
# ~400 KB/s, archive.apache.org rat cham nen de cuoi.
M=https://mirrors.huaweicloud.com/apache
U=https://mirrors.ustc.edu.cn/apache
D=https://dlcdn.apache.org
A=https://archive.apache.org/dist
# Tren GitHub Actions (may o My): archive.apache.org nhanh va on dinh hon mirror TQ
if [ -n "${CI:-}" ]; then M=$A; U=$A; fi

get "hadoop-${HADOOP_VERSION}.tar.gz" \
  "$M/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz" \
  "$A/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"

get "spark-${SPARK_VERSION}-bin-hadoop3.2.tgz" \
  "$M/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.2.tgz" \
  "$A/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.2.tgz"

get "scala-${SCALA_VERSION}.tgz" \
  "https://downloads.lightbend.com/scala/${SCALA_VERSION}/scala-${SCALA_VERSION}.tgz"

get "sbt-${SBT_VERSION}.tgz" \
  "https://github.com/sbt/sbt/releases/download/v${SBT_VERSION}/sbt-${SBT_VERSION}.tgz"

get "apache-flume-${FLUME_VERSION}-bin.tar.gz" \
  "$D/flume/${FLUME_VERSION}/apache-flume-${FLUME_VERSION}-bin.tar.gz" \
  "$U/flume/${FLUME_VERSION}/apache-flume-${FLUME_VERSION}-bin.tar.gz" \
  "$A/flume/${FLUME_VERSION}/apache-flume-${FLUME_VERSION}-bin.tar.gz"

get "hbase-${HBASE_VERSION}-hadoop3-bin.tar.gz" \
  "$D/hbase/${HBASE_VERSION}/hbase-${HBASE_VERSION}-hadoop3-bin.tar.gz" \
  "$U/hbase/${HBASE_VERSION}/hbase-${HBASE_VERSION}-hadoop3-bin.tar.gz" \
  "$A/hbase/${HBASE_VERSION}/hbase-${HBASE_VERSION}-hadoop3-bin.tar.gz"

# Pig da vao Apache Attic nen dlcdn khong con, chi con tren cac mirror
get "pig-${PIG_VERSION}.tar.gz" \
  "$U/pig/pig-${PIG_VERSION}/pig-${PIG_VERSION}.tar.gz" \
  "$M/pig/pig-${PIG_VERSION}/pig-${PIG_VERSION}.tar.gz" \
  "$A/pig/pig-${PIG_VERSION}/pig-${PIG_VERSION}.tar.gz"

echo
ls -lh *.tar.gz *.tgz
echo "ALL DOWNLOADS FINISHED"
