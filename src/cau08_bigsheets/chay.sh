#!/usr/bin/env bash
# Cau 8 - chay tren MAY THAT (Git Bash/Linux, can Docker): goi Rscript trong
# container rstudio, roi chuyen anh dashboard sang docs/images/ (container khong
# gan thu muc docs/). Dung: bash src/cau08_bigsheets/chay.sh
set -euo pipefail
cd "$(dirname "$0")"

MSYS_NO_PATHCONV=1 docker exec rstudio Rscript /home/rstudio/src/cau08_bigsheets/dashboard.R \
  2>&1 | tee output/log_chay.txt

mkdir -p ../../docs/images
mv -f output/hinh/cau08-*.png ../../docs/images/
rmdir output/hinh 2>/dev/null || true
echo "Da chuyen anh cau08-*.png sang docs/images/"
