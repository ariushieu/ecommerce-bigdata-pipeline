#!/usr/bin/env bash
# Demo Cau 10 - Doi chieu Pig - MapReduce - Spark (ssh may1):  bash ~/src/demo/cau10.sh
# shellcheck source=lib.sh disable=SC1091
. "$(dirname "$0")/lib.sh"
cd "$SRC" || exit 1
CSV=compare_category_month.csv

tieude "Cau 10 - Doi chieu Pig - MapReduce - Spark (bao cao muc 4.5, Chuong 5)"

buoc "Ba cong cu viet doc lap, cung ra tep danh muc x thang: ma bam giong het nhau"
lenh "md5sum cau04_pig/output/$CSV cau05_mapreduce/output/$CSV cau06_spark/output/$CSV"

buoc "So tung o (114 o) va doi chieu tong voi Cau 1"
lenh 'cd cau10_doi_chieu && python3 compare.py'

buoc "Thoi gian chay (trung vi 3 lan, giay; x10 = du lieu nhan 10 lan)"
lenh 'cat output/bench_avg.tsv'
