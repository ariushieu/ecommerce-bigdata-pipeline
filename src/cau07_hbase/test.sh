#!/usr/bin/env bash
# Cau 7 - kiem thu nhanh (CI): bien dich CustomerOrders.java, chay selftest tren bang tam
# btl:customer_orders_selftest (create -> put -> get -> scan thu tu -> version -> delete -> drop),
# sau do kiem tra lenh hbase shell co ban tren mot bang tam khac. Khong dung toi bang that.
set -euo pipefail
cd "$(dirname "$0")"

BUILD=$(mktemp -d)
LOG=$(mktemp)
SHELL_TABLE="btl:customer_orders_shelltest"
cleanup() {
  echo "if list.include?('$SHELL_TABLE') then (disable '$SHELL_TABLE' if is_enabled('$SHELL_TABLE')); drop '$SHELL_TABLE' end" \
    | hbase shell -n > /dev/null 2>&1 || true
  rm -rf "$BUILD" "$LOG"
}
trap cleanup EXIT

CP=$(hbase classpath)
javac -nowarn -cp "$CP" -d "$BUILD" CustomerOrders.java
echo "PASS: bien dich CustomerOrders.java"

# 1) Java Client API
java -Dtable=btl:customer_orders_selftest -cp "$BUILD:$CP" CustomerOrders selftest > "$BUILD/selftest.out" 2>"$LOG" || true
grep -E "^(PASS|FAIL|SELFTEST)" "$BUILD/selftest.out" || true
grep -q "SELFTEST OK" "$BUILD/selftest.out" || { tail -20 "$LOG"; echo "FAIL: selftest Java"; exit 1; }

# 2) hbase shell: create/put/get/scan/delete tren bang tam (namespace btl da duoc selftest tao)
cat > "$BUILD/t.rb" <<EOF
create '$SHELL_TABLE', {NAME => 'o', COMPRESSION => 'SNAPPY'}, {NAME => 'm'}, {NAME => 'd', VERSIONS => 5}
put '$SHELL_TABLE', 'C00941#9223370268000000000', 'm:net_revenue', '2703.86'
put '$SHELL_TABLE', 'C00941#9223370268000000001', 'm:net_revenue', '100.00'
get '$SHELL_TABLE', 'C00941#9223370268000000000'
scan '$SHELL_TABLE', {ROWPREFIXFILTER => 'C00941#'}
delete '$SHELL_TABLE', 'C00941#9223370268000000001', 'm:net_revenue'
count '$SHELL_TABLE'
EOF
hbase shell -n "$BUILD/t.rb" > "$LOG" 2>&1 || { tail -20 "$LOG"; echo "FAIL: hbase shell"; exit 1; }
# get thay gia tri, scan tien to thay 2 dong, sau khi delete cell duy nhat cua dong 2 thi count = 1
if grep -q "value=2703.86" "$LOG" && grep -qE "^2 row\(s\)" "$LOG" && grep -qE "^=> 1$" "$LOG"; then
  echo "PASS: hbase shell create/put/get/scan/delete/count"
else
  tail -20 "$LOG"
  echo "FAIL: hbase shell create/put/get/scan/delete/count"
  exit 1
fi
