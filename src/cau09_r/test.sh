#!/usr/bin/env bash
# Cau 9 - kiem tra output/ da commit (CI chay trong masternode, khong co R):
# chay lai truy van JOIN + GROUP BY bang sqlite3 cua Python va so voi CSV do R ghi;
# kiem tra tinh nhat quan cua ket qua hoi quy/phan loai. Neu co CSDL ket qua
# (output/project_data_results.sqlite, khong commit) thi kiem tra them cac bang da ghi.
#   cd ~/src/cau09_r && bash test.sh
set -euo pipefail
cd "$(dirname "$0")"

for f in tong_hop_danh_muc_phan_khuc.csv kiem_tra_o_trong.csv ma_tran_ty_le_tra.csv \
         tra_theo_yeu_to.csv hoi_quy_so_sanh.csv hoi_quy_he_so.csv phan_loai_chi_so.csv \
         phan_loai_thap_phan_vi.csv bang_ghi_lai_csdl.csv; do
  [ -s "output/$f" ] || { echo "FAIL: thieu output/$f - chay: bash chay.sh (tren may that)"; exit 1; }
done
echo "PASS: du cac file CSV ket qua trong output/"

python3 - "${DATA_DIR:-/data}/project_data.sqlite" <<'EOF'
import csv, os, sqlite3, sys

def doc(ten):
    with open("output/" + ten, encoding="utf-8") as f:
        return list(csv.DictReader(f))

bad = []
def check(ten, ok):
    print(("PASS: " if ok else "FAIL: ") + ten)
    if not ok:
        bad.append(ten)

LOC = "f.quality_flag NOT IN ('OUTLIER', 'DUPLICATE', 'LATE')"
con = sqlite3.connect("file:%s?mode=ro" % sys.argv[1], uri=True)
sql = """SELECT i.category, e.customer_segment, COUNT(*), COUNT(DISTINCT f.customer_id),
                SUM(f.net_revenue), SUM(f.returned_flag), AVG(NULLIF(f.review_score, ''))
         FROM fact_main f
         JOIN item_master i ON i.product_id = f.product_id
         JOIN entity_master e ON e.customer_id = f.customer_id
         WHERE %s GROUP BY 1, 2""" % LOC
ref = {(r[0], r[1]): r[2:] for r in con.execute(sql)}
rong = con.execute("SELECT SUM(review_score = ''), SUM(campaign_id = ''), AVG(review_score), "
                   "AVG(NULLIF(review_score, '')) FROM fact_main f WHERE " + LOC).fetchone()
con.close()

th = doc("tong_hop_danh_muc_phan_khuc.csv")
lech = [r["category"] + "/" + r["customer_segment"] for r in th
        if (r["category"], r["customer_segment"]) not in ref
        or int(r["orders"]) != ref[(r["category"], r["customer_segment"])][0]
        or int(r["customers"]) != ref[(r["category"], r["customer_segment"])][1]
        or abs(float(r["net_revenue"]) - ref[(r["category"], r["customer_segment"])][2]) > 0.01
        or int(r["returned"]) != ref[(r["category"], r["customer_segment"])][3]
        or abs(float(r["avg_review"]) - ref[(r["category"], r["customer_segment"])][4]) > 0.006]
check("SQL JOIN + GROUP BY (24 nhom danh muc x phan khuc) khop voi CSV" +
      (" (lech: %s)" % lech[:5] if lech else ""), len(th) == 24 == len(ref) and not lech)
check("tong: 14.408 don, 78.218.341,22 doanh thu, 1.114 don tra",
      sum(int(r["orders"]) for r in th) == 14408 and sum(int(r["returned"]) for r in th) == 1114
      and abs(sum(float(r["net_revenue"]) for r in th) - 78218341.22) < 0.05)

o = doc("kiem_tra_o_trong.csv")[0]
check("o trong '': 5.193 review_score, 165 campaign_id; AVG sai %.4f vs dung %.4f" % (rong[2], rong[3]),
      int(o["review_rong"]) == rong[0] == 5193 and int(o["campaign_rong"]) == rong[1] == 165
      and abs(float(o["avg_review_sai"]) - rong[2]) < 1e-4 and abs(float(o["avg_review_dung"]) - rong[3]) < 1e-4)

mt = doc("ma_tran_ty_le_tra.csv")
tt = {(r["category"], r["customer_segment"]): float(r["return_rate_pct"]) for r in th}
check("pivot_wider: ma tran ty le tra 6 x 4 khop bang dai",
      len(mt) == 6 and all(abs(float(r[s]) - tt[(r["category"], s)]) < 1e-9
                           for r in mt for s in ("Loyal", "New", "Regular", "VIP")))

yt = doc("tra_theo_yeu_to.csv")
nhom = {}
for r in yt:
    a = nhom.setdefault(r["yeu_to"], [0, 0])
    a[0] += int(r["orders"]); a[1] += int(r["returned"])
check("pivot_longer: moi yeu to (%d) cong lai dung 14.408 don / 1.114 tra" % len(nhom),
      len(nhom) == 7 and all(v == [14408, 1114] for v in nhom.values()))

ss = {r["mo_hinh"]: r for r in doc("hoi_quy_so_sanh.csv")}
r2 = {k: float(v["r2_test"]) for k, v in ss.items() if v["r2_test"] not in ("", "NA")}
check("hoi quy: M0 (cong thuc) R2 ~ 1, M1 < M2 < M3 tren tap test, R2 trong [0;1]",
      len(ss) == 5 and r2["M0_cong_thuc"] > 0.999
      and r2["M1_kinh_doanh"] < r2["M2_them_so_luong"] < r2["M3_them_gia_niem_yet"] <= 1)
hs = doc("hoi_quy_he_so.csv")
check("hoi quy M3: 18 he so, co log(list_price) va discount_10pp",
      len(hs) == 18 and {"log(list_price)", "discount_10pp"} <= {r["term"] for r in hs})

cs = doc("phan_loai_chi_so.csv")
n_test = int(cs[0]["n_test"])
ok = len(cs) == 3
for r in cs:
    ok = ok and int(r["tp"]) + int(r["fp"]) + int(r["tn"]) + int(r["fn"]) == n_test
    ok = ok and 0 <= float(r["auc_test"]) <= 1
base = int(cs[0]["tn"]) / n_test
check("phan loai: ma tran nham lan cong dung n_test = %d, AUC trong [0;1]" % n_test, ok)
check("phan loai: baseline accuracy = %.4f (ty le khong tra cua tap test)" % base,
      abs(float(cs[0]["accuracy"]) - round(base, 4)) < 1e-9)
check("chia train/test: %d + %d = 14.408" % (int(ss["M3_them_gia_niem_yet"]["n_train"]), n_test),
      int(ss["M3_them_gia_niem_yet"]["n_train"]) + n_test == 14408)
tp = doc("phan_loai_thap_phan_vi.csv")
check("thap phan vi: 10 nhom, cong lai = n_test", len(tp) == 10 and sum(int(r["orders"]) for r in tp) == n_test)

ghi = {r["bang"]: int(r["so_dong"]) for r in doc("bang_ghi_lai_csdl.csv")}
check("ghi lai CSDL: %d bang kq_*, kq_phan_loai_du_doan = n_test" % len(ghi),
      len(ghi) == 16 and all(k.startswith("kq_") for k in ghi) and ghi["kq_phan_loai_du_doan"] == n_test
      and ghi["kq_tong_hop_danh_muc_phan_khuc"] == 24)

db = "output/project_data_results.sqlite"
if os.path.exists(db):
    c = sqlite3.connect("file:%s?mode=ro" % db, uri=True)
    co = {t for (t,) in c.execute("SELECT name FROM sqlite_master WHERE type = 'table'")}
    dem = {t: c.execute('SELECT COUNT(*) FROM "%s"' % t).fetchone()[0] for t in ghi if t in co}
    goc = c.execute("SELECT COUNT(*) FROM fact_main").fetchone()[0]
    c.close()
    check("CSDL ket qua: du bang kq_* dung so dong, fact_main van 15.000 dong", dem == ghi and goc == 15000)
else:
    print("SKIP: khong co %s (file khong commit) - bo qua kiem tra CSDL ket qua" % db)
sys.exit(1 if bad else 0)
EOF
