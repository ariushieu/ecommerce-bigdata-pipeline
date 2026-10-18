#!/usr/bin/env bash
# Demo Cau 6 - PySpark (ssh may1):  bash ~/src/demo/cau06.sh   [nhanh]
# shellcheck source=lib.sh disable=SC1091
. "$(dirname "$0")/lib.sh" "$@"
cd "$SRC/cau06_spark" || exit 1

tieude "Cau 6 - Pipeline Spark (bao cao muc 2.4.2, 3.4, 4.2.2)"

buoc "Chay pipeline.py tren YARN (spark-submit)"
chay_lau 1 'bash run.sh'
lenh "grep -E '^(orders raw|curated|KET QUA)' output/pipeline_log.txt"

buoc "Vung curated: Parquet chia phan vung year/month/category"
lenh "hdfs dfs -ls -R /btl/curated/orders | awk '/^d/{print \$8}' | head -8"
lenh 'hdfs dfs -ls /btl/output/cau06_spark'

buoc "San pham tang truong nhanh (3 thang cuoi so voi 3 thang lien truoc)"
lenh "echo \"\$(( \$(wc -l < output/fast_growing_products.csv) - 1 )) san pham\"; head -6 output/fast_growing_products.csv | cut -d, -f1-5,10"

buoc "Khach hang co nguy co roi bo (RFM)"
lenh 'cat output/churn_summary.csv'
lenh "echo \"\$(( \$(wc -l < output/churn_risk_customers.csv) - 1 )) khach nguy co HIGH + MEDIUM\"; head -6 output/churn_risk_customers.csv | cut -d, -f1-6"

buoc "Thoi gian chay"
lenh 'tail -3 output/run_time.txt'

while IFS= read -r d; do kq "$d"; done < <(grep -E '^(orders raw|curated /btl)' output/pipeline_log.txt)
kq "San pham tang truong nhanh: $(( $(wc -l < output/fast_growing_products.csv) - 1 )) (3 thang cuoi so voi 3 thang lien truoc)"
kq "Khach co nguy co roi bo: $(( $(wc -l < output/churn_risk_customers.csv) - 1 )) ($(awk -F, '$1 == "ALL" { print $3 " HIGH + " $4 " MEDIUM" }' output/churn_summary.csv) / 1.200 khach)"
kq "Thoi gian lan chay moi nhat: $(tail -1 output/run_time.txt | cut -d, -f2) s"
web http://localhost:18080 "Spark History: bam app moi nhat > Jobs (action), Stages (shuffle), Storage (cache), SQL"
web http://localhost:9870  "HDFS: Utilities > Browse the file system > /btl/curated/orders (Parquet year/month/category)"
tong_ket
