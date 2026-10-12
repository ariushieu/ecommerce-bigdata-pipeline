#!/usr/bin/env bash
# Cau 4 - Kiem thu script Pig o che do local (khong can HDFS/YARN) tren du lieu mau nho,
# roi kiem tra ket qua that da commit trong output/.
#   cd ~/src/cau04_pig && bash test.sh
set -euo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
FAIL=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAIL=1; }

# Dung cay thu muc raw giong HDFS; them BOM + CRLF nhu tep that (tep trong Git la LF)
SNAP=2026-08-01
lap() {  # lap <bang> <tep_mau> <ten_tep> <co_bom>
  local d="$TMP/raw/$1/ingest_date=$SNAP"
  mkdir -p "$d"
  if [ "$4" = 1 ]; then
    { printf '\xEF\xBB\xBF'; sed 's/$/\r/' "tests/fixtures/$2"; } > "$d/$3"
  else
    cp "tests/fixtures/$2" "$d/$3"
  fi
}
lap orders orders_small.csv orders.csv 1
lap customers customers_small.csv customers.csv 1
lap products products_small.csv products.csv 1
lap events events_small.jsonl events_stream.jsonl 0

pig -x local -param RAW="$TMP/raw" -param STAGING="$TMP/staging/orders" \
    -param OUT="$TMP/out" -param PAR=1 -f cau04.pig > "$TMP/pig.out" 2> "$TMP/pig.log" \
  || { echo "FAIL: pig -x local loi"; grep -E "ERROR|Exception" "$TMP/pig.log" | head -20; exit 1; }

gop() { cat "$TMP/out/$1"/part-* | LC_ALL=C sort; }   # gop <ten_ket_qua> (da sap xep)

# TC1: so lieu tung buoc lam sach (FILTER, SPLIT, DISTINCT, JOIN)
want=$(printf '%s\n' "distinct_content_rows	22" "join_catalog_mismatch	0" \
  "join_enriched_orders	19" "raw_status_DUPLICATE	1" "raw_status_HEADER	1" \
  "raw_status_INVALID	2" "raw_status_LATE	1" "raw_status_MISSING	1" "raw_status_OK	18" \
  "raw_status_OUTLIER	1" | LC_ALL=C sort)
nrej=$(cat "$TMP/out/rejected_orders"/part-* | wc -l)
if [ "$(gop checks)" = "$want" ] && [ "$nrej" = 3 ]; then
  pass "TC1 lam sach: header 1, invalid 2, SPLIT giu 19 (OK 18 + MISSING 1) / loai $nrej, JOIN 19"
else fail "TC1 lam sach (rejected=$nrej)"; diff <(gop checks) <(echo "$want") || true; fi

# TC2: tep doi chieu dung quy uoc (tieu de tu .pig_header, sap xep, lam tron HALF_UP)
{ cat "$TMP/out/compare_category_month/.pig_header" "$TMP/out/compare_category_month"/part-*; } > "$TMP/cm.csv"
if diff "$TMP/cm.csv" tests/expected/compare_category_month.csv > /dev/null; then
  pass "TC2 compare_category_month: 7 dong, Books 2025-01 = 3100.30 / 50.00%, 2/3 -> 66.67"
else fail "TC2 compare_category_month"; diff "$TMP/cm.csv" tests/expected/compare_category_month.csv || true; fi

# TC3: vung staging: 19 dong, 24 cot tab, khong BOM/CR, MISSING: review NULL, campaign NONE
st=$(cat "$TMP/staging/orders"/part-*)
n=$(printf '%s\n' "$st" | wc -l)
cols=$(printf '%s\n' "$st" | awk -F'\t' '{ print NF }' | sort -u | paste -sd' ')
t3=$(printf '%s\n' "$st" | awk -F'\t' '$1 == "T0003" { print $21 "|" $22 "|" $24 }')
if [ "$n" = 19 ] && [ "$cols" = 24 ] && [ "$t3" = "|NONE|2025-01" ] \
   && ! printf '%s' "$st" | grep -q $'\r\|\xEF\xBB\xBF'; then
  pass "TC3 staging: $n dong x $cols cot, T0003 review=NULL campaign=NONE"
else fail "TC3 staging: $n dong, cot=[$cols], T0003=[$t3]"; fi

# TC4: su kien JSON (JsonLoader, truong long payload) doi chieu voi don hang
want=$(printf '%s\n' "MISSING	1	1" "NO_ORDER	1	0" "OK	2	1" "OUTLIER	1	1")
if [ "$(gop event_check)" = "$want" ]; then pass "TC4 su kien: phat hien 1 lech, 1 khong co don"
else fail "TC4 su kien"; diff <(gop event_check) <(echo "$want") || true; fi

# TC5: ket qua that da commit: tong khop Cau 1 va trung tung o voi MapReduce (Cau 5)
if [ -f output/compare_category_month.csv ]; then
  tong=$(awk -F, 'NR > 1 { n += $3; c += $4 * 100; r += $5 } END { printf "orders=%d net_revenue=%.2f returned=%d", n, c / 100, r }' \
    output/compare_category_month.csv)
  if [ "$tong" = "orders=14408 net_revenue=78218341.22 returned=1114" ] \
     && [ "$(wc -l < output/compare_category_month.csv)" = 115 ]; then
    pass "TC5 output/compare_category_month.csv: 114 o, $tong"
  else fail "TC5 tong output/compare_category_month.csv: $tong"; fi
  MR=../cau05_mapreduce/output/compare_category_month.csv
  if [ -f "$MR" ]; then
    if diff -q output/compare_category_month.csv "$MR" > /dev/null; then
      pass "TC6 Pig va MapReduce: compare_category_month.csv giong het nhau"
    else fail "TC6 Pig va MapReduce khac nhau"; fi
  fi
else
  fail "Chua co output/compare_category_month.csv - chay: bash run.sh"
fi

[ "$FAIL" = 0 ]
