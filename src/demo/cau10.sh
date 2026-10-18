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

cd "$SRC" || exit 1
kq "md5 ba tep compare_category_month.csv: $(md5sum cau0[456]_*/output/$CSV | awk '{ print $1 }' | sort -u | wc -l | sed 's/^1$/giong het nhau/; s/^[0-9]*$/KHAC NHAU/')"
kq "$(grep -m1 'So o sai khac' cau10_doi_chieu/output/doi_chieu.md) tren 114 o danh muc x thang; tong 14.408 don, 78.218.341,22, 1.114 don tra (khop Cau 1)"
kq "Thoi gian (giay, x1 / x10): $(awk -F'\t' '{ t[$1] = t[$1] (t[$1] ? " / " : "") $3 } END { printf "MapReduce %s; Spark %s; Pig %s", t["MapReduce"], t["Spark"], t["Pig"] }' cau10_doi_chieu/output/bench_avg.tsv)"
kq "Khuyen nghi: bao cao Chuong 5"
tong_ket
