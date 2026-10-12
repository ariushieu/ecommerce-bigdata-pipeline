#!/usr/bin/env python3
# Cau 5 - So sanh tai cua 3 reducer theo 3 cach chia (tinh tu ket qua that):
#   (a) CategoryPartitioner: bang anh xa tuong minh (mac dinh cua job)
#   (b) bam category: (String.hashCode(category) & MAX) % 3  (nhanh du phong cua CategoryPartitioner)
#   (c) HashPartitioner mac dinh cua Hadoop: (Text.hashCode(khoa day du) & MAX) % 3
#   python3 partition_balance.py output/category_province_month.tsv > output/partition_balance.txt
import sys
from collections import defaultdict

N = 3
MAPPING = {"Beauty": 0, "Books": 0, "Electronics": 1, "Fashion": 1, "Home": 2, "Sports": 2}


def i32(x):
    x &= 0xFFFFFFFF
    return x - (1 << 32) if x >= (1 << 31) else x


def java_string_hash(s):   # String.hashCode (UTF-16, o day toan ASCII)
    h = 0
    for ch in s:
        h = i32(31 * h + ord(ch))
    return h


def text_hash(s):          # org.apache.hadoop.io.Text.hashCode = WritableComparator.hashBytes
    h = 1
    for b in s.encode("utf-8"):
        h = i32(31 * h + (b - 256 if b > 127 else b))
    return h


def main():
    rows = []
    with open(sys.argv[1], encoding="utf-8") as f:
        for line in f:
            cat, prov, month, orders = line.rstrip("\n").split("\t")[:4]
            rows.append((cat, prov, month, int(orders)))
    cach = {
        "(a) CategoryPartitioner (bang anh xa)": lambda r: MAPPING[r[0]],
        "(b) hash(category) % 3": lambda r: (java_string_hash(r[0]) & 0x7FFFFFFF) % N,
        "(c) HashPartitioner(khoa day du) % 3": lambda r: (text_hash("\t".join(r[:3])) & 0x7FFFFFFF) % N,
    }
    tong = sum(r[3] for r in rows)
    print("Tong: %d nhom khoa, %d don sach; ly tuong %.0f don/reducer" % (len(rows), tong, tong / N))
    for ten, fn in cach.items():
        don = defaultdict(int)
        nhom = defaultdict(int)
        dm = defaultdict(set)
        for r in rows:
            p = fn(r)
            don[p] += r[3]
            nhom[p] += 1
            dm[p].add(r[0])
        print()
        print(ten)
        for p in range(N):
            print("  reducer %d: %5d don, %4d nhom, danh muc: %s"
                  % (p, don[p], nhom[p], ",".join(sorted(dm[p])) or "-"))
        print("  lech tai (max/trung binh): %.3f" % (max(don[p] for p in range(N)) / (tong / N)))


if __name__ == "__main__":
    main()
