#!/usr/bin/env bash
# Cau 5 - Bien dich ma nguon Java MapReduce thanh cau05.jar (chay trong may1).
#   bash cau05_mapreduce/build.sh            # dong cuoi in ra: JAR=<duong dan>
#   JAR=$(bash build.sh | sed -n 's/^JAR=//p')
# Dung javac cua JDK 8 voi classpath lay tu "hadoop classpath" (khong can Maven).
# *.class, *.jar khong dua len Git: luon bien dich lai tu ma nguon.
# Mac dinh ghi vao build/ canh ma nguon; neu thu muc src khong ghi duoc
# (vd. CI tren Linux: src thuoc user cua runner) thi ghi vao $TMPDIR.
set -euo pipefail
cd "$(dirname "$0")"

B=${CAU05_BUILD:-build}
if ! { mkdir -p "$B" && [ -w "$B" ]; } 2>/dev/null; then
  B=${TMPDIR:-/tmp}/cau05_build
fi
rm -rf "$B/classes"
mkdir -p "$B/classes"
javac -source 8 -target 8 -Xlint:all,-path -cp "$(hadoop classpath)" \
  -d "$B/classes" java/btl/cau05/*.java
jar cf "$B/cau05.jar" -C "$B/classes" .
echo "JAR=$(cd "$B" && pwd)/cau05.jar"
