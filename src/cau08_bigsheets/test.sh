#!/usr/bin/env bash
# Cau 8 - kiem tra output/ da commit (khong can R): tinh lai tu /data/orders.csv
# bang Python thu vien chuan va so tung o voi bang dashboard.
#   cd ~/src/cau08_bigsheets && bash test.sh
set -euo pipefail
cd "$(dirname "$0")"

for f in kpi.csv buoc_bigsheets.csv dashboard_category_province.csv dashboard_category.csv \
         dashboard_province.csv dashboard_month.csv dashboard_revenue_bucket.csv; do
  [ -s "output/$f" ] || { echo "FAIL: thieu output/$f - chay: bash chay.sh (tren may that)"; exit 1; }
done
echo "PASS: du 7 file CSV trong output/"

python3 - "${DATA_DIR:-/data}/orders.csv" <<'EOF'
import csv, sys
from collections import defaultdict

def doc(ten):
    with open("output/" + ten, encoding="utf-8") as f:
        return list(csv.DictReader(f))

# Tinh lai: bo OUTLIER/DUPLICATE/LATE, gom theo (category, province)
g = defaultdict(lambda: [0, 0.0, 0, 0.0, 0])   # don, doanh thu, tra, tong ngay giao, tre
with open(sys.argv[1], encoding="utf-8-sig", newline="") as f:
    for r in csv.DictReader(f):
        if r["quality_flag"] in ("OUTLIER", "DUPLICATE", "LATE"):
            continue
        x = g[(r["category"], r["province"])]
        d = float(r["delivery_days"])
        x[0] += 1; x[1] += float(r["net_revenue"]); x[2] += int(r["returned_flag"])
        x[3] += d; x[4] += d > 5

bad = []
def check(ten, ok):
    print(("PASS: " if ok else "FAIL: ") + ten)
    if not ok:
        bad.append(ten)

cp = doc("dashboard_category_province.csv")
check("dashboard_category_province: 108 o (6 danh muc x 18 tinh)", len(cp) == 108 == len(g))
lech = []
for r in cp:
    x = g.get((r["category"], r["province"]))
    if x is None:
        lech.append(r["category"] + "/" + r["province"]); continue
    if (int(r["orders"]) != x[0] or abs(float(r["net_revenue"]) - x[1]) > 0.01
            or int(r["returned"]) != x[2] or int(r["late_orders"]) != x[4]
            or abs(float(r["avg_delivery_days"]) - x[3] / x[0]) > 0.006
            or abs(float(r["return_rate_pct"]) - 100 * x[2] / x[0]) > 0.006):
        lech.append(r["category"] + "/" + r["province"])
check("tung o dashboard khop voi tinh lai tu orders.csv" + (" (lech: %s)" % lech[:5] if lech else ""),
      not lech)

k = doc("kpi.csv")[0]
check("KPI: 14.408 don, doanh thu 78.218.341,22, 1.114 tra (7,73%)",
      int(k["orders"]) == 14408 and abs(float(k["net_revenue"]) - 78218341.22) < 0.01
      and int(k["returned"]) == 1114 and float(k["return_rate_pct"]) == 7.73)
check("KPI: giao TB 3,04 ngay; 1.010 don > 5 ngay (7,01%)",
      float(k["avg_delivery_days"]) == 3.04 and int(k["late_orders"]) == 1010
      and float(k["late_pct"]) == 7.01)

for ten, n in (("dashboard_category.csv", 6), ("dashboard_province.csv", 18),
               ("dashboard_month.csv", 19), ("dashboard_revenue_bucket.csv", 4)):
    t = doc(ten)
    ok = (len(t) == n and sum(int(r["orders"]) for r in t) == 14408
          and sum(int(r["returned"]) for r in t) == 1114
          and abs(sum(float(r["net_revenue"]) for r in t) - 78218341.22) < 0.05)
    check("%s: %d dong, cong lai dung tong" % (ten, n), ok)

buoc = doc("buoc_bigsheets.csv")
dau = {}
for r in buoc:
    dau.setdefault(r["buoc"], int(r["so_dong"]))   # dong dau tien cua moi buoc
check("buoc BigSheets: 15.000 -> loc 14.408 -> join van 14.408",
      buoc[0]["mo_ta"].startswith("Collection orders") and dau["B1"] == 15000
      and dau["B3"] == 14408 and dau["B5"] == 14408)
sys.exit(1 if bad else 0)
EOF
