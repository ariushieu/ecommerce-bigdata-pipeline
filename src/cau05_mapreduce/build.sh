#!/usr/bin/env bash
# Cau 5 - Bien dich ma nguon Java MapReduce thanh build/cau05.jar (chay trong may1).
#   bash cau05_mapreduce/build.sh
# Dung javac cua JDK 8 voi classpath lay tu "hadoop classpath" (khong can Maven).
# *.class, *.jar khong dua len Git: luon bien dich lai tu ma nguon.
set -euo pipefail
cd "$(dirname "$0")"

rm -rf build
mkdir -p build/classes
javac -source 8 -target 8 -Xlint:all,-path -cp "$(hadoop classpath)" \
  -d build/classes java/btl/cau05/*.java
jar cf build/cau05.jar -C build/classes .
echo "Da tao $(pwd)/build/cau05.jar"
