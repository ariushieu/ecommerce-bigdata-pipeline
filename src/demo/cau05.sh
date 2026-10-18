#!/usr/bin/env bash
# Demo Cau 5 - MapReduce Java (ssh may1):  bash ~/src/demo/cau05.sh   [nhanh]
# shellcheck source=lib.sh disable=SC1091
. "$(dirname "$0")/lib.sh" "$@"
cd "$SRC/cau05_mapreduce" || exit 1
OUT=/btl/output/cau05_mr

tieude "Cau 5 - MapReduce: Mapper, Combiner, Partitioner, Reducer (bao cao muc 3.5, 4.1)"

buoc "Ma nguon Java: moi lop mot vai tro"
lenh "grep -hE '^public (final )?class' java/btl/cau05/*.java"

buoc "Chay 3 job tren YARN: co Combiner, tat Combiner, gop danh muc x thang"
chay_lau 1 'bash run.sh'

buoc "Combiner: 14.408 ban ghi map -> 2.049 ban ghi qua shuffle (giam 85,8%)"
lenh "grep -hE 'COMBINER|COMBINE_(INPUT|OUTPUT)_RECORDS|REDUCE_SHUFFLE_BYTES' output/counters_category_province_month.txt output/counters_category_province_month_nocombiner.txt"

buoc "Partitioner: 6 danh muc chia deu cho 3 reducer"
lenh 'cat output/partitions.txt'

buoc "Ket qua tren HDFS (danh muc, tinh, thang, so don, doanh thu, so don tra, ty le tra)"
lenh "hdfs dfs -ls $OUT/category_province_month"
lenh "hdfs dfs -cat $OUT/category_province_month/part-r-00000 2>/dev/null | head -5"
lenh 'cat output/runtime.txt'

buoc "5 test case (TC1-TC5): lam sach, Combiner, Partitioner, tinh toan, doi chieu du lieu that"
chay_lau 1 "bash test.sh | grep -E '^(PASS|FAIL)'"

C=output/counters_category_province_month.txt
cnt() { awk -F'\t' -v k="$2" '$1 == "COUNTER" && $3 == k { print $4 }' "$1"; }
CI=$(cnt $C COMBINE_INPUT_RECORDS); CO=$(cnt $C COMBINE_OUTPUT_RECORDS)
SB=$(cnt $C REDUCE_SHUFFLE_BYTES); SB0=$(cnt output/counters_category_province_month_nocombiner.txt REDUCE_SHUFFLE_BYTES)
kq "Combiner: $CI -> $CO ban ghi qua shuffle (giam $(awk -v a="$CI" -v b="$CO" 'BEGIN { printf "%.1f", 100 * (a - b) / a }')%); shuffle $SB0 -> $SB byte"
kq "$(grep -m1 'Combiner bat/tat' output/runtime.txt)"
kq "Partitioner: $(awk -F'\t' 'NR > 1 { printf "%s%s=%s", s, $1, $4; s = ", " }' output/partitions.txt)"
kq "$(grep -m1 '^orders=' output/runtime.txt) (khop Cau 1)"
kq "Thoi gian: $(awk -F'\t' '/wall_s=/ { printf "%s%s %s s", s, $1, substr($2, 8); s = "; " }' output/runtime.txt)"
JOB=$(grep -m1 'JOB_ID' $C | awk -F'\t' '{ print $2 }')
web http://localhost:19888 "JobHistory: bam job cau05 category_province_month${JOB:+ ($JOB)} > menu trai Counters"
web http://localhost:9870  "HDFS: Utilities > Browse the file system > /btl/output/cau05_mr"
tong_ket
