#!/usr/bin/env bash
# Cau 9 - chay tren MAY THAT (Git Bash/Linux, can Docker): goi Rscript trong
# container rstudio, roi chuyen anh bieu do sang docs/images/ (container khong
# gan thu muc docs/). Dung: bash src/cau09_r/chay.sh
set -euo pipefail
cd "$(dirname "$0")"

MSYS_NO_PATHCONV=1 docker exec rstudio Rscript /home/rstudio/src/cau09_r/phan_tich.R \
  2>&1 | tee output/log_chay.txt

mkdir -p ../../docs/images
mv -f output/hinh/cau09-*.png ../../docs/images/
rmdir output/hinh 2>/dev/null || true
echo "Da chuyen anh cau09-*.png sang docs/images/"
