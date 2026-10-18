#!/usr/bin/env bash
# Demo Cau 9 - R + SQLite: SQL, dplyr, hoi quy, phan loai. Chay tren MAY THAT (Git Bash, thu muc goc kho ma):
#   bash src/demo/cau09.sh   [nhanh]
# shellcheck source=lib.sh disable=SC1091
. "$(dirname "$0")/lib.sh" "$@"
cd "$SRC/cau09_r" || exit 1
IMG=$(cd "$SRC/../docs/images" && pwd)

tieude "Cau 9 - Phan tich bang R tren project_data.sqlite (bao cao muc 4.2, 4.3)"

buoc "Chay phan_tich.R: ket noi SQLite, truy van SQL, dplyr, hoi quy, phan loai, ghi ket qua"
chay_lau 1 'bash chay.sh > /dev/null 2>&1'
lenh "sed -n '/^== 1/,/^== 3/p' output/log_chay.txt | head -12"

buoc "Hoi quy doanh thu: R2 tang dan khi them bien, M3 dat R2 test = 0,833"
lenh 'cat output/hoi_quy_so_sanh.csv'

buoc "Phan loai tra hang: AUC 0,49 ~ mo hinh co so, du lieu khong co tin hieu (kiem dinh chi2)"
lenh "awk -v FPAT='([^,]*)|(\"[^\"]*\")' -v OFS=' | ' '{print \$1, \$7, \$9, \$12}' output/phan_loai_chi_so.csv"
lenh 'cat output/kiem_dinh_chi2.csv'

buoc "Ket qua ghi lai vao CSDL SQLite"
lenh 'cat output/bang_ghi_lai_csdl.txt'

buoc "Mo bieu do"
lenh "ls ../../docs/images | grep cau09-"
mo_anh "$IMG/cau09-hoi-quy-phan-du.png"
mo_anh "$IMG/cau09-roc.png"
web "RStudio http://localhost:8787 (mo src/cau09_r/phan_tich.R)"
