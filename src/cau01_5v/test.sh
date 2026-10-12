#!/usr/bin/env bash
# Cau 1 - chay lai profiling va kiem tra so lieu ma bao cao dang trich dan.
set -euo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

python3 profile_data.py --data "${DATA_DIR:-/data}" --out "$TMP" >/dev/null

# 1) output/ da commit phai trung voi ket qua chay lai (bao cao khong dung so cu)
if ! diff -q output/profile.json "$TMP/profile.json" >/dev/null; then
  echo "FAIL: output/profile.json da cu - chay lai: python3 profile_data.py"
  diff <(head -c 4000 output/profile.json) <(head -c 4000 "$TMP/profile.json") | head -20 || true
  exit 1
fi
echo "PASS: output/profile.json khop voi du lieu"

# 2) Bat bien cua bo du lieu (neu sai thi phan tich 5V phai viet lai)
python3 - "$TMP/profile.json" <<'EOF'
import json, sys
p = json.load(open(sys.argv[1], encoding="utf-8"))
vr, ve, vo = p["veracity"], p["velocity"], p["volume"]
checks = [
    ("15.000 don, 23 cot", vo["files"][0]["rows"] == 15000 and vo["files"][0]["columns"] == 23),
    ("5.000 su kien", ve["events"] == 5000),
    ("tong quality_flag = 15.000", sum(vr["quality_flag"].values()) == 15000),
    ("su kien khop don goc", vr["events_vs_orders"] == {}),
    ("SQLite fact_main = orders.csv", vr["sqlite_rows_differing_from_csv"] == 0),
    ("khong co khoa mo coi", vr["integrity"]["orphan_customer_id"] == 0
                             and vr["integrity"]["orphan_product_id"] == 0),
    ("chi OUTLIER sai cong thuc", sum(v for k, v in vr["net_revenue_formula_fail_by_flag"].items()
                                     if k != "OUTLIER") == 0),
    ("lam sach con 14.408 don", vr["rows_after_cleaning_rule"] == 14408),
]
bad = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(("PASS: " if ok else "FAIL: ") + name)
sys.exit(1 if bad else 0)
EOF
