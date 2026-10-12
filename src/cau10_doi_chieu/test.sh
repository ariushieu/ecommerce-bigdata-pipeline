#!/usr/bin/env bash
# Cau 10 - Kiem tra: ket qua category x thang cua Pig, MapReduce, Spark khop tung o
# va khop tong cua Cau 1; cu phap Pig/Python cua ban do hieu nang hop le.
set -euo pipefail
cd "$(dirname "$0")"

python3 compare.py --out "${TMPDIR:-/tmp}/cau10_doi_chieu.md" > /dev/null
echo "PASS: Pig = MapReduce = Spark tung o, tong khop Cau 1"

python3 -m py_compile spark_category_month.py compare.py
echo "PASS: cu phap Python"

pig -x local -c -param IN=x -param OUT=y -f category_month.pig 2>&1 | grep -q 'syntax OK'
echo "PASS: cu phap Pig"

if [ -f output/bench.tsv ]; then
  grep -q '^# x1: 3 cong cu cho ket qua giong het nhau' output/bench.tsv
  grep -q '^# x10: 3 cong cu cho ket qua giong het nhau' output/bench.tsv
  echo "PASS: bench.tsv - 3 cong cu cung ket qua o x1 va x10"
fi
