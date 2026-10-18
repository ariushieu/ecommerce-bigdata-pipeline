#!/usr/bin/env bash
# Demo Cau 2 - Flume lo + luong (ssh may1):  bash ~/src/demo/cau02.sh   [nhanh]
# shellcheck source=lib.sh disable=SC1091
. "$(dirname "$0")/lib.sh" "$@"
cd "$SRC/cau02_flume" || exit 1

tieude "Cau 2 - Thu thap du lieu bang Flume (bao cao muc 1.5, 3.3)"

buoc "Cau hinh 2 agent: b1 (spooldir -> HDFS) va s1 (HTTP -> HDFS + HBase)"
lenh "grep -hE '\\.(type|spoolDir|deletePolicy|port|hdfs\\.path|table|capacity) = ' conf/batch-csv.conf conf/stream-events.conf"

buoc "Kich ban (i) theo lo: nap orders, customers, products vao /btl/raw"
chay_lau 1 'bash run_batch.sh'
lenh 'tail -8 output/batch_run.txt'

buoc "Kich ban (ii) theo luong: gui 5.000 su kien HTTP, roi gui lai 1.000 su kien (mo phong loi mang)"
chay_lau 1 'bash run_stream.sh > /dev/null 2>&1'
lenh "grep -E '^== (3|4|6|7)|REPLAY|so dong HDFS|count|PASS|FAIL' output/stream_run.txt"

buoc "Chong mat du lieu: kill -9 agent, so sanh FileChannel va MemoryChannel"
chay_lau 2 'bash crash_demo.sh > /dev/null 2>&1'
lenh "sed -n '/^== 4/,\$p' output/crash_demo.txt"

for f in output/batch_run.txt output/stream_run.txt output/crash_demo.txt; do
  while IFS= read -r d; do kq "$d"; done < <(grep -E '^(PASS|FAIL)' "$f")
done
web http://localhost:16010 "HBase: muc Tables > btl:order_events (bang su kien vua ghi)"
web http://localhost:9870  "HDFS: Utilities > Browse the file system > /btl/raw/events"
tong_ket
