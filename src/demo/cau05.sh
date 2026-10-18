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
web "JobHistory http://localhost:19888 (xem Counters cua tung job)"
