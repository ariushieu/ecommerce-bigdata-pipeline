#!/usr/bin/env python3
"""Cau 10 - Doi chieu tung o ket qua category x thang cua Pig, MapReduce va Spark.

    python3 compare.py [--out output/doi_chieu.md]

Doc src/cau04_pig, cau05_mapreduce, cau06_spark /output/compare_category_month.csv,
so tung o voi nhau va voi tong cua Cau 1 (src/cau01_5v/output/profile.json).
Thoat ma 1 neu co bat ky sai khac nao.
"""
import argparse
import csv
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.dirname(HERE)
TOOLS = [("Pig", "cau04_pig"), ("MapReduce", "cau05_mapreduce"), ("Spark", "cau06_spark")]
COLS = ["orders", "net_revenue", "returned", "return_rate_pct"]


def load(d):
    path = os.path.join(SRC, d, "output", "compare_category_month.csv")
    with open(path, encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    return {(r["category"], r["month"]): r for r in rows}, open(path, "rb").read()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(HERE, "output", "doi_chieu.md"))
    a = ap.parse_args()

    data = {name: load(d) for name, d in TOOLS}
    ref_name = TOOLS[0][0]
    ref = data[ref_name][0]
    problems = []
    for name, (rows, _) in data.items():
        if set(rows) != set(ref):
            problems.append(f"{name}: tap o (category, thang) khac {ref_name}")
            continue
        for key, r in rows.items():
            for c in COLS:
                if r[c] != ref[key][c]:
                    problems.append(f"{name} {key} {c}: {r[c]} != {ref[key][c]}")

    prof = json.load(open(os.path.join(SRC, "cau01_5v", "output", "profile.json"), encoding="utf-8"))
    expect = (prof["value"]["clean_orders"], prof["value"]["net_revenue_total"],
              prof["value"]["returned_orders"])
    lines = ["| Công cụ | Số ô | Tổng đơn | Tổng doanh thu | Tổng đơn trả | Khớp Câu 1 | Giống từng byte với Pig |",
             "|---|---:|---:|---:|---:|---|---|"]
    for name, (rows, raw) in data.items():
        n = sum(int(r["orders"]) for r in rows.values())
        rev = round(sum(round(float(r["net_revenue"]) * 100) for r in rows.values()) / 100, 2)
        ret = sum(int(r["returned"]) for r in rows.values())
        ok = (n, rev, ret) == expect
        if not ok:
            problems.append(f"{name}: tong ({n}, {rev}, {ret}) != Cau 1 {expect}")
        same = raw == data[ref_name][1]
        lines.append(f"| {name} | {len(rows)} | {n:,} | {rev:,.2f} | {ret:,} | {'có' if ok else 'KHÔNG'} | "
                     f"{'có' if same else 'không'} |".replace(",", "X").replace(".", ",").replace("X", "."))

    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n\n")
        f.write(f"So o sai khac: {len(problems)}\n")
        for p in problems:
            f.write(f"- {p}\n")
    print("\n".join(lines))
    print(f"So o sai khac: {len(problems)}")
    for p in problems[:20]:
        print("  " + p)
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
