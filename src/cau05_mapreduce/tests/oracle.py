#!/usr/bin/env python3
# Cau 5 - "Oracle" doc lap (Python thu vien chuan, so thap phan chinh xac Decimal)
# de kiem tra ket qua cua MapReduce (Cau 5) va Pig (Cau 4).
#   python3 oracle.py <orders.csv> <muc> <tep_ra>
#   muc = category_month          -> CSV dung quy uoc docs/quy-uoc.md muc 3 (co tieu de)
#         category_province_month -> TSV khong tieu de, cung dinh dang output cua MapReduce
# In ra stderr: so don sach, tong doanh thu, so don tra (doi chieu voi Cau 1).
import csv
import sys
from collections import defaultdict
from decimal import Decimal, ROUND_HALF_UP

BO = {"OUTLIER", "DUPLICATE", "LATE"}   # quy tac lam sach chung


def main():
    src, muc, dst = sys.argv[1], sys.argv[2], sys.argv[3]
    agg = defaultdict(lambda: [0, Decimal(0), 0])
    tong = [0, Decimal(0), 0]
    with open(src, encoding="utf-8-sig", newline="") as f:   # utf-8-sig: bo BOM
        for row in csv.DictReader(f):
            if row["quality_flag"] in BO:
                continue
            month = row["timestamp"][:7]
            if muc == "category_month":
                key = (row["category"], month)
            else:
                key = (row["category"], row["province"], month)
            a = agg[key]
            rev = Decimal(row["net_revenue"])
            ret = int(row["returned_flag"])
            a[0] += 1
            a[1] += rev
            a[2] += ret
            tong[0] += 1
            tong[1] += rev
            tong[2] += ret
    q = Decimal("0.01")
    with open(dst, "w", encoding="utf-8", newline="\n") as out:
        if muc == "category_month":
            out.write("category,month,orders,net_revenue,returned,return_rate_pct\n")
            sep = ","
        else:
            sep = "\t"
        for key in sorted(agg):
            n, rev, ret = agg[key]
            rate = (Decimal(100 * ret) / Decimal(n)).quantize(q, ROUND_HALF_UP)
            out.write(sep.join(list(key) + [str(n), str(rev.quantize(q, ROUND_HALF_UP)),
                                            str(ret), str(rate)]) + "\n")
    sys.stderr.write("orders=%d net_revenue=%s returned=%d\n"
                     % (tong[0], tong[1].quantize(q, ROUND_HALF_UP), tong[2]))


if __name__ == "__main__":
    main()
