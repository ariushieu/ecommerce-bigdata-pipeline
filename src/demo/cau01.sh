#!/usr/bin/env bash
# Demo Cau 1 - 5V va chat luong du lieu (ssh may1):  bash ~/src/demo/cau01.sh
# shellcheck source=lib.sh disable=SC1091
. "$(dirname "$0")/lib.sh"
cd "$SRC/cau01_5v" || exit 1

tieude "Cau 1 - Dac trung 5V va chat luong du lieu (bao cao muc 1.3, 2.1-2.3)"

buoc "Du lieu goc cua de: 3 dinh dang (CSV, JSON Lines, SQLite)"
lenh 'ls -l /data'
lenh 'head -3 /data/orders.csv'
lenh 'head -2 /data/events_stream.jsonl'

buoc "Chay profiling: do Volume, Velocity, Variety, Veracity, Value tu du lieu that"
lenh 'python3 profile_data.py'

buoc "Volume: dung luong, so ban ghi"
lenh "sed -n '/^## Volume/,/^## Velocity/p' output/profile.md | head -16"

buoc "Veracity: loi du lieu (OUTLIER, DUPLICATE, LATE, MISSING, su kien sai thu tu)"
lenh "sed -n '/^## Veracity/,/^## Value/p' output/profile.md"

buoc "Value: chi so kinh doanh sau lam sach"
lenh "sed -n '/^## Value/,\$p' output/profile.md | head -25"

P=output/profile.md
kq "Volume: $(grep -m1 '^- Tổng:' $P | sed 's/^- Tổng: //; s/\*\*//g')"
kq "Velocity: su kien $(grep -m1 'cặp liên tiếp bị ngược' $P | grep -oE '[0-9]+,[0-9]+%') cap lien tiep den sai thu tu thoi gian"
kq "Veracity: $(grep -m1 'Quy tắc làm sạch' $P | sed 's/^- //; s/\*\*//g')"
kq "Value: $(grep -m1 'Doanh thu ròng' $P | sed 's/^- //; s/\*\*//g')"
kq "$(grep -m1 '^- Trả hàng' $P | sed 's/^- //; s/\*\*//g')"
kq "$(grep -m1 '^- Giao hàng' $P | sed 's/^- //; s/\*\*//g')"
kq "Chi tiet: ~/src/cau01_5v/output/profile.md (bao cao muc 1.3, 2.1-2.3)"
tong_ket
