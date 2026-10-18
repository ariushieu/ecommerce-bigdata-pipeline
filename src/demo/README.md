# Script demo

Hướng dẫn demo đầy đủ (ai demo, lệnh, trang web cần mở, nội dung cần nói) nằm ở [`DEMO.md`](../../DEMO.md) tại thư mục gốc kho mã.

| Script | Câu |
|---|---|
| `cau00_chuan_bi.sh` | Bật cụm, smoke-test, nạp bản chụp chuẩn |
| `cau01.sh` … `cau07.sh`, `cau10.sh` | Demo từng câu (chạy trong `ssh may1`) |
| `cau03_hong_node.sh` | Tắt DataNode trên datanode3 qua ssh, theo dõi HDFS tự khôi phục |
| `lib.sh` | Hàm dùng chung: in lệnh, chờ Enter, chế độ `nhanh` |

Câu 8, 9 demo trong RStudio (`localhost:8787`), xem `DEMO.md`.

`NOPAUSE=1 bash cauNN.sh` chạy một mạch không chờ Enter (dùng để chạy thử). Sau khi chạy, muốn trả `src/*/output/` về bản đã nộp thì chạy `git restore src` ở thư mục gốc.
