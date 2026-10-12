#!/usr/bin/env bash
# Cau 5 - Kiem thu MapReduce o che do local (khong can HDFS/YARN), du lieu mau nho.
#   cd ~/src/cau05_mapreduce && bash test.sh
# TC1  Doc/lam sach : bo BOM + tieu de + CRLF, dong hong; bo OUTLIER/DUPLICATE/LATE, giu MISSING (Counter)
# TC2  Combiner     : bat/tat Combiner cho cung ket qua; Combiner giam so ban ghi qua shuffle
# TC3  Partitioner  : moi danh muc ve dung reducer; noi part-r-* duoc thu tu toan cuc
# TC4  Tinh toan    : gop danh muc x thang, cong tien chinh xac, lam tron ty le HALF_UP
# TC5  Du lieu that : output/ da commit trung voi oracle Python doc lap + tong khop Cau 1
set -euo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
FAIL=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAIL=1; }

bash build.sh >/dev/null

# Du lieu mau: them BOM + CRLF giong orders.csv that (tep trong Git luon la LF)
mkdir -p "$TMP/in"
{ printf '\xEF\xBB\xBF'; sed 's/$/\r/' tests/fixtures/orders_small.csv; } > "$TMP/in/orders.csv"

chay() {  # chay <ten> [-D ...]  -> $TMP/<ten>/ (output), $TMP/<ten>.out (counter)
  local ten=$1; shift
  hadoop jar build/cau05.jar btl.cau05.RevenueReturnJob \
    -D mapreduce.framework.name=local -fs file:/// "$@" \
    "file://$TMP/in" "file://$TMP/$ten" > "$TMP/$ten.out" 2> "$TMP/$ten.err" \
    || { echo "Job $ten loi:"; tail -30 "$TMP/$ten.err"; exit 1; }
}
counter() {  # counter <ten> <ten_counter>
  awk -F'\t' -v c="$2" '$1 == "COUNTER" && $3 == c { print $4 }' "$TMP/$1.out"
}

chay cpm
chay cpm_nocomb -D cau05.combiner=false
chay cm -D cau05.level=category_month

# --- TC1 --------------------------------------------------------------------
want="HEADER_SKIPPED=1 MALFORMED=2 DROP_OUTLIER=1 DROP_DUPLICATE=1 DROP_LATE=1 KEPT_OK=18 KEPT_MISSING=1 MAP_INPUT_RECORDS=25 MAP_OUTPUT_RECORDS=19"
got=""
for kv in $want; do got="$got ${kv%%=*}=$(counter cpm "${kv%%=*}")"; done
if [ "${got# }" = "$want" ]; then pass "TC1 lam sach: $want"
else fail "TC1 lam sach: mong doi [$want], nhan [${got# }]"; fi

# --- TC2 --------------------------------------------------------------------
ci=$(counter cpm COMBINE_INPUT_RECORDS); co=$(counter cpm COMBINE_OUTPUT_RECORDS)
ci0=$(counter cpm_nocomb COMBINE_INPUT_RECORDS)
if diff <(cat "$TMP"/cpm/part-r-*) <(cat "$TMP"/cpm_nocomb/part-r-*) >/dev/null \
   && [ "$ci" = 19 ] && [ "$co" = 8 ] && [ "$ci0" = 0 ]; then
  pass "TC2 combiner: co/khong Combiner cung ket qua; combine in=$ci out=$co (tat: in=$ci0)"
else fail "TC2 combiner: in=$ci out=$co tat=$ci0 hoac ket qua khac nhau"; fi

# --- TC3 --------------------------------------------------------------------
p0=$(cut -f1 "$TMP/cpm/part-r-00000" | sort -u | paste -sd' ')
p1=$(cut -f1 "$TMP/cpm/part-r-00001" | sort -u | paste -sd' ')
p2=$(cut -f1 "$TMP/cpm/part-r-00002" | sort -u | paste -sd' ')
if [ "$p0|$p1|$p2" = "Beauty Books|Electronics Fashion|Home Sports" ] \
   && diff <(cat "$TMP"/cpm/part-r-*) tests/expected/category_province_month.tsv >/dev/null; then
  pass "TC3 partitioner: r0=[$p0] r1=[$p1] r2=[$p2]; noi part-r-* = ket qua mong doi (da sap xep)"
else
  fail "TC3 partitioner: r0=[$p0] r1=[$p1] r2=[$p2]"
  diff <(cat "$TMP"/cpm/part-r-*) tests/expected/category_province_month.tsv || true
fi

# --- TC4 --------------------------------------------------------------------
if diff <(cat "$TMP"/cm/part-r-*) tests/expected/category_month.tsv >/dev/null; then
  pass "TC4 tinh toan: Books 2025-01 = 4 don, 3100.30, tra 50.00%; 2/3 -> 66.67; 1/8 -> 12.50"
else
  fail "TC4 tinh toan"
  diff <(cat "$TMP"/cm/part-r-*) tests/expected/category_month.tsv || true
fi

# --- TC5 --------------------------------------------------------------------
ORDERS=${DATA_DIR:-/data}/orders.csv
if [ -f "$ORDERS" ]; then
  python3 -I tests/oracle.py "$ORDERS" category_month "$TMP/oracle_cm.csv" 2> "$TMP/tong.txt"
  python3 -I tests/oracle.py "$ORDERS" category_province_month "$TMP/oracle_cpm.tsv" 2>/dev/null
  tong=$(cat "$TMP/tong.txt")
  if diff output/compare_category_month.csv "$TMP/oracle_cm.csv" >/dev/null \
     && diff output/category_province_month.tsv "$TMP/oracle_cpm.tsv" >/dev/null \
     && [ "$tong" = "orders=14408 net_revenue=78218341.22 returned=1114" ]; then
    pass "TC5 du lieu that: output/ khop oracle Python; $tong"
  else
    fail "TC5 du lieu that: output/ khac oracle hoac tong sai ($tong) - chay lai: bash run.sh"
  fi
else
  echo "SKIP: TC5 (khong thay $ORDERS)"
fi

[ "$FAIL" = 0 ]
