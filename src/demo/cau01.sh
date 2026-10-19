#!/usr/bin/env bash
# Demo Cau 1 - 5V va chat luong du lieu (ssh may1):  bash ~/src/demo/cau01.sh
# shellcheck source=lib.sh disable=SC1091
. "$(dirname "$0")/lib.sh"
cd "$SRC/cau01_5v" || exit 1
P=output/profile.md

# muc <ten muc>: in cac dong gach dau dong (khong in bang) cua mot muc trong profile.md
muc() { sed -n "/^## $1/,/^## /p" $P | grep '^- ' | sed 's/\*\*//g'; }
# dong <mau>: mot dong cua profile.md, bo "- " va dau **
dong() { grep -m1 "$1" $P | sed 's/^- //; s/\*\*//g; s/`//g; s/\.$//'; }

tieude "Cau 1 - Dac trung 5V va chat luong du lieu (bao cao muc 1.3, 2.1-2.3)"

buoc "Du lieu goc cua de: 3 dinh dang (CSV, JSON Lines, SQLite)"
lenh 'ls -l /data'
lenh 'head -3 /data/orders.csv'
lenh 'head -2 /data/events_stream.jsonl'

buoc "Chay profiling: do Volume, Velocity, Variety, Veracity, Value tu du lieu that"
lenh 'python3 profile_data.py'

buoc "1. Volume: dung luong, so ban ghi"
lenh "sed -n '/^## Volume/,/^## Velocity/p' $P | grep -v '^## Velocity'"

buoc "2. Velocity: toc do phat sinh, che do nap, su kien den sai thu tu"
lenh "muc Velocity"

buoc "3. Variety: dinh dang, ma hoa, nguon, cau truc JSON"
lenh "muc Variety"

buoc "4. Veracity: loi du lieu (OUTLIER, DUPLICATE, LATE, MISSING) va quy tac lam sach"
lenh "sed -n '/^## Veracity/,/^## Value/p' $P | grep -v '^## Value'"

buoc "5. Value: chi so kinh doanh sau lam sach"
lenh "sed -n '/^## Value/,\$p' $P | head -25"

kq "Volume: $(dong '^- Tổng:' | sed 's/^Tổng: //')"
kq "Velocity: $(dong '^- Đơn/ngày' | sed 's/;.*//'); $(grep -m1 'cặp liên tiếp bị ngược' $P | grep -oE '[0-9]+,[0-9]+%') cap su kien lien tiep den sai thu tu"
kq "Variety: 3 dinh dang tep (CSV, JSON Lines, SQLite); 5 nguon ($(dong '^- .source_system' | sed -E 's/^source_system: //; s/ [0-9.]+//g')); $(dong '^- Nhãn .data_format' | sed 's/^Nhãn //')"
kq "Veracity: $(dong 'Quy tắc làm sạch')"
kq "Value: $(dong 'Doanh thu ròng' | cut -d, -f1-2); $(dong '^- Trả hàng' | cut -d, -f1-2); $(dong '^- Giao hàng' | sed 's/, P90.*//')"
kq "Chi tiet: ~/src/cau01_5v/output/profile.md (bao cao muc 1.3, 2.1-2.3)"
tong_ket
