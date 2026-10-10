# shellcheck shell=bash
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HBASE_MANAGES_ZK=true
export HBASE_HEAPSIZE=768m
export HBASE_LOG_DIR=/home/hadoop/hbase/logs
export HBASE_PID_DIR=/tmp
export HBASE_SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
# Ban hbase-*-hadoop3 da kem san thu vien Hadoop client; khong tron them jar
# cua Hadoop 3.2.2 cai rieng (tranh xung dot phien ban).
export HBASE_DISABLE_HADOOP_CLASSPATH_LOOKUP=true
