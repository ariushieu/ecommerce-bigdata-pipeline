#!/usr/bin/env bash
# Cau 5 - Tom tat ket qua MapReduce (output/category_province_month.tsv) cho bao cao:
#   output/province_summary.tsv : gop theo tinh giao hang (18 tinh), sap theo doanh thu giam dan
#   output/cell_stats.txt       : phan bo so don moi o (danh muc x tinh x thang), cac o noi bat
#   bash summarize.sh            (run.sh tu goi o cuoi)
set -euo pipefail
cd "$(dirname "$0")"
IN=output/category_province_month.tsv

# Cot: category province month orders net_revenue returned return_rate_pct
# Tien cong bang xu (so nguyen) de khong sai so dau phay dong
{ printf 'province\torders\tnet_revenue\treturned\treturn_rate_pct\n'
  awk -F'\t' '{ n[$2] += $4; c[$2] += sprintf("%.0f", $5 * 100); r[$2] += $6 }
    END { for (p in n) printf "%s\t%d\t%.2f\t%d\t%.2f\n", p, n[p], c[p] / 100, r[p], 100 * r[p] / n[p] }' "$IN" \
    | sort -t$'\t' -k3,3gr
} > output/province_summary.tsv

{
  echo "So o (danh muc x tinh x thang) co don: $(wc -l < "$IN") / $((6 * 18 * 19)) o co the co"
  cut -f4 "$IN" | sort -n | awk '{ a[NR] = $1; s += $1 }
    END { printf "So don moi o: nho nhat %d, trung vi %d, lon nhat %d, trung binh %.2f\n", a[1], a[int((NR + 1) / 2)], a[NR], s / NR }'
  awk -F'\t' '$6 == 0 { z++ } END { printf "O khong co don tra: %d (%.1f%%)\n", z, 100 * z / NR }' "$IN"
  echo
  echo "5 o doanh thu cao nhat:"
  sort -t$'\t' -k5,5gr "$IN" | awk 'NR <= 5'
  echo
  echo "5 o ty le tra cao nhat (chi xet o co >= 15 don):"
  awk -F'\t' '$4 >= 15' "$IN" | sort -t$'\t' -k7,7gr -k4,4nr | awk 'NR <= 5'
  echo
  echo "Danh muc x thang (compare_category_month.csv): ty le tra thap nhat / cao nhat"
  tail -n +2 output/compare_category_month.csv | sort -t, -k6,6g | awk 'NR == 1'
  tail -n +2 output/compare_category_month.csv | sort -t, -k6,6g | tail -1
} > output/cell_stats.txt
cat output/cell_stats.txt
