#!/usr/bin/env bash
# Demo Cau 8 - Dashboard theo quy trinh BigSheets. Chay tren MAY THAT (Git Bash, thu muc goc kho ma):
#   bash src/demo/cau08.sh   [nhanh]
# shellcheck source=lib.sh disable=SC1091
. "$(dirname "$0")/lib.sh" "$@"
cd "$SRC/cau08_bigsheets" || exit 1
IMG=$(cd "$SRC/../docs/images" && pwd)

tieude "Cau 8 - Quy trinh BigSheets va dashboard (bao cao muc 4.3, Phu luc C)"

buoc "Cac buoc BigSheets (Workbook -> Sheet -> Filter -> Group -> Chart), lam lai bang R"
lenh 'cat output/buoc_bigsheets.csv'

buoc "Chay dashboard.R (doc du lieu sach, tong hop, ve 6 bieu do)"
chay_lau 1 'bash chay.sh > /dev/null 2>&1'

buoc "KPI tong va bang tong hop theo danh muc"
lenh 'cat output/kpi.csv'
lenh 'cat output/dashboard_category.csv'

buoc "Mo dashboard"
lenh "ls ../../docs/images | grep cau08-"
mo_anh "$IMG/cau08-dashboard.png"
web "RStudio http://localhost:8787 (mo src/cau08_bigsheets/dashboard.R)"
