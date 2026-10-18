# Script demo trước giảng viên

Mỗi câu có một script. Script in ra từng lệnh (màu xanh) rồi mới chạy, và **dừng chờ Enter trước mỗi bước** để người trình bày kịp giải thích. Thêm `nhanh` vào sau tên script để bỏ qua các bước chạy lâu và chỉ in kết quả của lần chạy trước. Dùng khi máy chậm hoặc hết giờ.

## Trước giờ demo (làm từ tối hôm trước)

Mở **Git Bash** ở thư mục gốc kho mã:

```bash
docker compose up -d
ssh may1
bash ~/src/demo/cau00_chuan_bi.sh      # bật cụm, smoke-test phải ra 8 PASS, nạp bản chụp chuẩn
```

Chạy thử một lượt cả 10 câu, nếu có câu nào lỗi thì vẫn kịp sửa. Mở sẵn trên trình duyệt: `localhost:9870` (HDFS), `localhost:19888` (JobHistory), `localhost:18080` (Spark), `localhost:16010` (HBase), `localhost:8787` (RStudio).

## Trong buổi demo

Cửa sổ 1, chạy trong `ssh may1` (Câu 1–7, 10):

| Câu | Người | Lệnh | Thời gian | Bản `nhanh` |
|---|---|---|---|---|
| 1 | Hiếu | `bash ~/src/demo/cau01.sh` | 10 s | |
| 2 | Duy | `bash ~/src/demo/cau02.sh` | 4 phút | `bash ~/src/demo/cau02.sh nhanh` |
| 3 | Duy | `bash ~/src/demo/cau03.sh` | 30 s | |
| 4 | Hiệp | `bash ~/src/demo/cau04.sh` | **6 phút** | `bash ~/src/demo/cau04.sh nhanh` |
| 5 | Hiệp | `bash ~/src/demo/cau05.sh` | 2 phút | `bash ~/src/demo/cau05.sh nhanh` |
| 6 | Quốc | `bash ~/src/demo/cau06.sh` | 1 phút | `bash ~/src/demo/cau06.sh nhanh` |
| 7 | Quốc | `bash ~/src/demo/cau07.sh` | 2 phút | `bash ~/src/demo/cau07.sh nhanh` |
| 10 | Hiếu | `bash ~/src/demo/cau10.sh` | 10 s | |

Cửa sổ 2, chạy trong **Git Bash trên máy thật**, ở thư mục gốc kho mã (Câu 8, 9 cần container R):

| Câu | Người | Lệnh | Thời gian | Bản `nhanh` |
|---|---|---|---|---|
| 8 | Quyết | `bash src/demo/cau08.sh` | 1 phút | `bash src/demo/cau08.sh nhanh` |
| 9 | Quyết | `bash src/demo/cau09.sh` | 1 phút | `bash src/demo/cau09.sh nhanh` |

Câu 4 chạy 17 job nên lâu nhất. Có hai cách:

- Mở thêm một cửa sổ `ssh may1` và chạy `bash ~/src/demo/cau04.sh` ngay khi bắt đầu buổi, đến lượt Câu 4 thì quay lại cửa sổ đó.
- Hoặc dùng `bash ~/src/demo/cau04.sh nhanh`, sau đó mở JobHistory để chỉ các job đã chạy.

Câu 3 chỉ in log của lần tắt node thật. Nếu giảng viên muốn xem tắt node trực tiếp, chạy trên máy thật (mất khoảng 4 phút, trong lúc đó không chạy job khác):

```bash
bash src/cau03_hdfs/recovery_demo.sh
```

## Nếu có sự cố

| Hiện tượng | Cách xử lý |
|---|---|
| `ssh may1` báo lỗi kết nối | `docker compose up -d`, chờ 30 s rồi thử lại |
| Lệnh `hdfs`/`yarn` treo hoặc báo Connection refused | `start-cluster.sh` rồi `smoke-test.sh` |
| HBase báo "Master is initializing" kéo dài | `hbase-reset.sh`, sau đó chạy lại Câu 2 và Câu 7 |
| Hết giờ hoặc máy chậm | Thêm `nhanh` sau tên script |

Chạy xong, kết quả trong `src/*/output/` có thể đổi thời gian chạy. Muốn trả về bản đã nộp thì chạy `git restore src docs/images`.
