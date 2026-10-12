#!/usr/bin/env bash
# Cau 6 - kiem thu (CI): chay lai pipeline Spark vao thu muc tam (HDFS + local), so voi
# output/ da commit va kiem tra cac so lieu chinh ma bao cao trich dan. Khong ghi de
# /btl/curated hay /btl/output that.
set -euo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
H=/tmp/cau06_test_$$
trap 'hdfs dfs -rm -r -f -skipTrash "$H" > /dev/null 2>&1 || true; rm -rf "$TMP"' EXIT

python3 -c "import sys; [compile(open(f).read(), f, 'exec') for f in sys.argv[1:]]" pipeline.py bench.py category_month_only.py
echo "PASS: pipeline.py, bench.py, category_month_only.py bien dich duoc (Python $(python3 -V 2>&1 | cut -d' ' -f2))"

bash ../cau03_hdfs/init_zones.sh > /dev/null
if ! spark-submit pipeline.py --out "$H/out" --curated "$H/curated" --local-out "$TMP" > "$TMP/spark.log" 2>&1; then
  grep -vE "^[0-9]{2}/[0-9]{2}/[0-9]{2} " "$TMP/spark.log" | tail -30
  echo "FAIL: spark-submit pipeline.py"
  exit 1
fi
echo "PASS: spark-submit pipeline.py tren YARN"

FAIL=0
# 1) output/ da commit phai trung voi ket qua chay lai
for f in compare_category_month.csv fast_growing_products.csv churn_risk_customers.csv \
         churn_summary.csv growth_by_category.csv reconcile_events.csv growth_summary.csv churn_by_risk.csv; do
  if diff -q "output/$f" "$TMP/$f" > /dev/null; then
    echo "PASS: output/$f khop"
  else
    echo "FAIL: output/$f da cu - chay lai: bash cau06_spark/run.sh"
    diff "output/$f" "$TMP/$f" | head -5 || true
    FAIL=1
  fi
done

# 2) so lieu chinh (quy uoc muc 2, 3; profile Cau 1)
python3 - "$TMP" <<'EOF' || FAIL=1
import csv, os, sys
from decimal import Decimal
d = sys.argv[1]
cm = list(csv.DictReader(open(os.path.join(d, "compare_category_month.csv"), encoding="utf-8")))
rec = {r["metric"]: r["value"] for r in csv.DictReader(open(os.path.join(d, "reconcile_events.csv"), encoding="utf-8"))}
raw = open(os.path.join(d, "compare_category_month.csv"), "rb").read()
checks = [
    ("tieu de compare_category_month dung quy uoc",
     list(cm[0].keys()) == ["category", "month", "orders", "net_revenue", "returned", "return_rate_pct"]),
    ("114 o danh muc x thang, sap theo category, month",
     len(cm) == 114 and [(r["category"], r["month"]) for r in cm] == sorted((r["category"], r["month"]) for r in cm)),
    ("tong don sach = 14.408", sum(int(r["orders"]) for r in cm) == 14408),
    ("tong doanh thu = 78.218.341,22", sum(Decimal(r["net_revenue"]) for r in cm) == Decimal("78218341.22")),
    ("tong don tra = 1.114", sum(int(r["returned"]) for r in cm) == 1114),
    ("xuong dong LF, khong BOM", b"\r\n" not in raw and not raw.startswith(b"\xef\xbb\xbf")),
    ("5.000 su kien khop 5.000 don, 0 truong lech",
     rec["matched_orders"] == "5000" and all(rec[k] == "0" for k in rec if k.startswith("diff_"))),
]
for name, ok in checks:
    print(("PASS: " if ok else "FAIL: ") + name)
sys.exit(0 if all(ok for _, ok in checks) else 1)
EOF

# 3) vung curated: Parquet phan vung year/month/category, doc lai du 14.408 dong
N=$(grep -oE "curated .*: [0-9]+ dong, [0-9]+ phan vung" "$TMP/pipeline_log.txt" || true)
if [[ "$N" == *": 14408 dong, 114 phan vung"* ]] \
   && hdfs dfs -test -d "$H/curated/year=2026/month=07/category=Books"; then
  echo "PASS: curated Parquet 14.408 dong, 114 phan vung year=YYYY/month=MM/category=<cat>"
else
  echo "FAIL: curated ($N)"
  FAIL=1
fi
exit "$FAIL"
