# Script demo trước giảng viên

Mỗi câu có một script. Script in ra từng lệnh (màu xanh) rồi mới chạy, và **dừng chờ Enter trước mỗi bước** để người trình bày kịp giải thích. Thêm `nhanh` vào sau tên script để bỏ qua các bước chạy lâu và chỉ in kết quả của lần chạy trước. Dùng khi máy chậm hoặc hết giờ.

## 1. Chuẩn bị (làm trước giờ demo)

1. Nhấp đúp `scripts\mo-terminal.cmd`. Máy sẽ mở 4 tab: `may1` (masternode), `may2`, `may3`, `may4` (datanode1–3).
2. Trong tab `may1`, chạy:

   ```bash
   bash ~/src/demo/cau00_chuan_bi.sh
   ```

   Script bật cụm, chạy smoke-test (phải ra 8 PASS) và nạp bản chụp chuẩn.
3. Mở sẵn trên trình duyệt:
   - `localhost:9870` (HDFS)
   - `localhost:19888` (JobHistory)
   - `localhost:18080` (Spark)
   - `localhost:16010` (HBase)
   - `localhost:8787` (RStudio)

## 2. Trong buổi demo

### Câu 1–7 và 10: tab `may1`

| Câu | Người | Lệnh | Thời gian |
|---|---|---|---|
| 1 | Hiếu | `bash ~/src/demo/cau01.sh` | 10 s |
| 2 | Duy | `bash ~/src/demo/cau02.sh` | 3 phút |
| 3 | Duy | `bash ~/src/demo/cau03.sh` | 10 s |
| 4 | Hiệp | `bash ~/src/demo/cau04.sh` | **5 phút** |
| 5 | Hiệp | `bash ~/src/demo/cau05.sh` | 1,5 phút |
| 6 | Quốc | `bash ~/src/demo/cau06.sh` | 1 phút |
| 7 | Quốc | `bash ~/src/demo/cau07.sh` | 1,5 phút |
| 10 | Hiếu | `bash ~/src/demo/cau10.sh` | 10 s |

Lưu ý riêng cho Câu 3 và Câu 4:

- **Câu 4 (5 phút):** ngay khi bắt đầu buổi, mở thêm một tab, gõ `ssh may1` rồi chạy `bash ~/src/demo/cau04.sh`. Đến lượt Câu 4 thì chuyển sang tab đó. Chỉ `may1` có thư mục `~/src`. Nếu thiếu thời gian, dùng `bash ~/src/demo/cau04.sh nhanh`.
- **Câu 3:** nếu giảng viên muốn xem hỏng node trực tiếp, chạy `bash ~/src/demo/cau03_hong_node.sh` (khoảng 4 phút, trong lúc đó không chạy job khác).
  - Script ssh sang `datanode3` và tắt DataNode.
  - Sau đó đọc lại tệp, chờ NameNode đánh dấu node chết và tự nhân bản lại.
  - Cuối cùng bật lại DataNode.
  - Trong lúc chờ, mở `localhost:9870` → Datanodes để thấy `datanode3` chuyển sang Dead.

### Câu 8, 9: RStudio trên trình duyệt (`localhost:8787`)

Gõ vào khung **Console**:

| Câu | Người | Lệnh trong Console | Xem kết quả |
|---|---|---|---|
| 8 | Quyết | `setwd("~/src/cau08_bigsheets"); source("dashboard.R")` | Files → `src/cau08_bigsheets/output/hinh/cau08-dashboard.png` |
| 9 | Quyết | `setwd("~/src/cau09_r"); source("phan_tich.R")` | Files → `src/cau09_r/output/hinh/cau09-roc.png`; bảng kết quả trong `output/*.csv` |

Mỗi lệnh chạy khoảng 1 phút. Nên mở file `.R` ở khung soạn thảo để giải thích mã trong lúc chạy.

## 3. Nếu có sự cố

| Hiện tượng | Cách xử lý (tab `may1`) |
|---|---|
| Lệnh `hdfs`/`yarn` treo hoặc báo Connection refused | `start-cluster.sh` rồi `smoke-test.sh` |
| HBase báo "Master is initializing" kéo dài | `hbase-reset.sh`, sau đó chạy lại Câu 2 và Câu 7 |
| Hết giờ hoặc máy chậm | Thêm `nhanh` sau tên script |
| Tab ssh bị đóng | Nhấp đúp lại `scripts\mo-terminal.cmd` |

Sau buổi demo, các tệp trong `src/*/output/` sẽ đổi số đo thời gian. Muốn trả về bản đã nộp thì chạy `git restore src docs/images` ở thư mục gốc kho mã.
