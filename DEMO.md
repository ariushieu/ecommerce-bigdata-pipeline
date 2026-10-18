# Hướng dẫn demo BTL – Đề 01

Mỗi câu ghi rõ bốn thứ: **ai demo**, **chạy lệnh ở đâu**, **mở trang web nào để xem**, và **nói gì**.

Script demo in lệnh màu xanh trước khi chạy và **dừng chờ Enter ở mỗi bước**. Người demo bấm Enter, chờ kết quả hiện ra, giải thích xong mới bấm tiếp.

Thêm chữ `nhanh` sau lệnh (ví dụ `bash ~/src/demo/cau04.sh nhanh`) để bỏ qua bước chạy lâu và chỉ in kết quả của lần chạy trước. Dùng khi máy chậm hoặc hết giờ.

---

## Bước 0. Chuẩn bị (trước khi vào lớp 15 phút)

| # | Việc | Cách làm |
|---|---|---|
| 1 | Mở 4 terminal của cụm | Nhấp đúp `scripts\mo-terminal.cmd` → hiện 4 tab: `may1` (masternode), `may2`, `may3`, `may4` (datanode1–3) |
| 2 | Bật cụm và kiểm tra | Ở tab `may1`: `bash ~/src/demo/cau00_chuan_bi.sh`, bấm Enter qua từng bước. Smoke-test phải ra **8 PASS** |
| 3 | Mở sẵn 6 tab trình duyệt | Theo bảng dưới |
| 4 | Mở sẵn báo cáo | Mở `BaoCao.pdf` để lật tới bảng, hình khi giải thích |

**Các trang web của cụm** (mở bằng Chrome hoặc Edge):

| Địa chỉ | Là gì | Dùng cho câu |
|---|---|---|
| `localhost:9870` | HDFS NameNode: DataNode, thư mục, block | 2, 3 |
| `localhost:8088` | YARN ResourceManager: các job đang chạy hoặc đã chạy | 4, 5, 6 |
| `localhost:19888` | JobHistory: chi tiết job MapReduce, Counters | 4, 5 |
| `localhost:18080` | Spark History: DAG, stage, cache của job Spark | 6 |
| `localhost:16010` | HBase Master: bảng, region, RegionServer | 2, 7 |
| `localhost:8787` | RStudio: chạy code R, xem biểu đồ | 8, 9 |

---

## Câu 1 – Đặc trưng 5V, chất lượng dữ liệu (Hiếu)

| | |
|---|---|
| **Báo cáo** | Mục 1.3, 2.1–2.3 |
| **Lệnh (tab `may1`)** | `bash ~/src/demo/cau01.sh` |
| **Thời gian** | 10 giây |
| **Web** | Không cần |

**Nói:**
- **Dữ liệu:** 7 MB, gồm 3 định dạng (CSV, JSON Lines, SQLite) và 5 nguồn.
- **Velocity:** trung bình 26 đơn/ngày.
- **Veracity:** 6,03% bản ghi bị gắn cờ lỗi (OUTLIER, DUPLICATE, LATE, MISSING); 50,27% sự kiện đến sai thứ tự.
- **Sau làm sạch:** 15.000 → **14.408** đơn.
- **Value:** doanh thu 78.218.341,22; tỷ lệ trả **7,73%**; giao trung bình **3,04 ngày**.

---

## Câu 2 – Thu thập bằng Flume (Duy)

| | |
|---|---|
| **Báo cáo** | Mục 1.5, 3.3 |
| **Lệnh (tab `may1`)** | `bash ~/src/demo/cau02.sh` |
| **Thời gian** | 3 phút |
| **Web** | `localhost:16010` → mục Tables → `btl:order_events` (bảng sự kiện vừa ghi vào). `localhost:9870` → Utilities → Browse the file system → `/btl/raw/events` |

**Nói:**
- **Hai agent:** `b1` đọc thư mục (spooldir) → HDFS, chạy theo lô; `s1` nhận HTTP → HDFS và HBase, chạy theo luồng.
- **Gửi 5.000 sự kiện, rồi gửi lại 1.000 (mô phỏng lỗi mạng):**
  - HDFS có 6.000 dòng, tức nhận *ít nhất một lần*.
  - HBase vẫn đúng 5.000 dòng, vì rowkey `event_id` ghi đè được.
- **Kill -9 agent:** FileChannel giữ **1000/1000** sự kiện, MemoryChannel **mất cả 1000**.

---

## Câu 3 – Lưu trữ HDFS, nhân bản, hỏng node (Duy)

| | |
|---|---|
| **Báo cáo** | Mục 3.2.1 |
| **Lệnh (tab `may1`)** | `bash ~/src/demo/cau03.sh` (10 giây, in kết quả lần tắt node trước) |
| **Hỏng node trực tiếp (nếu cô yêu cầu)** | `bash ~/src/demo/cau03_hong_node.sh` (khoảng 4 phút, không chạy job khác cùng lúc) |
| **Web** | `localhost:9870` → **Datanodes**: 3 node In Service. Trong lúc chạy hỏng node, bấm F5 để thấy `datanode3` chuyển sang **Dead**. Utilities → Browse the file system → `/btl`: 4 vùng |

**Nói:**
- **4 vùng:** raw → staging → curated → output.
- **Nhân bản:** 3 lần, nên 6,9 MB dữ liệu chiếm 20,7 MB.
- **Kết quả tắt DataNode trên datanode3:**
  - Đọc lại ngay vẫn đúng: md5 khớp.
  - Khoảng **143 s** sau, NameNode đánh dấu node chết (2 × 60 s recheck + 10 × 3 s heartbeat).
  - Khoảng **181 s**, tệp đã được nhân bản lại sang node còn sống.
  - Bật lại node thì HDFS **HEALTHY**.

---

## Câu 4 – Pig Latin (Hiệp)

| | |
|---|---|
| **Báo cáo** | Mục 2.4.1, 3.5, 4.1 |
| **Lệnh** | **Chạy từ đầu buổi:** mở thêm một tab, gõ `ssh may1`, rồi chạy `bash ~/src/demo/cau04.sh` (5 phút). Đến lượt thì quay lại tab này |
| **Hết giờ thì dùng** | `bash ~/src/demo/cau04.sh nhanh` |
| **Web** | `localhost:8088`: thấy các job `PigLatin:cau04.pig` đang chạy hoặc đã xong. `localhost:19888`: danh sách 17 job MapReduce mà Pig sinh ra |

**Nói:**
- **Các toán tử dùng trong script:** LOAD, FILTER, SPLIT (tách đơn sạch và đơn bị loại), FOREACH, JOIN replicated (bảng danh mục nhỏ), GROUP, ORDER, LIMIT, STORE.
- **Kết quả làm sạch:** 15.000 → 14.408 đơn sạch, 592 đơn bị loại.
- **Vì sao chạy lâu:** Pig dịch thành **17 job MapReduce**, mỗi job tốn thời gian khởi động.

---

## Câu 5 – MapReduce Java (Hiệp)

| | |
|---|---|
| **Báo cáo** | Mục 3.5, 4.1 |
| **Lệnh (tab `may1`)** | `bash ~/src/demo/cau05.sh` |
| **Thời gian** | 1,5 phút |
| **Web** | `localhost:19888` → bấm vào job `cau05 category_province_month` → menu trái **Counters** → nhóm Map-Reduce Framework: `Combine input records = 14408`, `Combine output records = 2049` |

**Nói:**
- **Các lớp:**
  - `RevenueMapper` đọc và lọc, phát ra cặp (danh mục, tỉnh, tháng) → thống kê.
  - `StatsCombiner` cộng sẵn ở phía map.
  - `CategoryPartitioner` chia 6 danh mục cho 3 reducer.
  - `RateReducer` tính tỷ lệ trả.
- **Combiner:** giảm **85,8%** số bản ghi qua shuffle, và bật hay tắt đều cho cùng một kết quả.
- **Kiểm thử:** 5 test case TC1–TC5 đều PASS.

---

## Câu 6 – Spark (Quốc)

| | |
|---|---|
| **Báo cáo** | Mục 2.4.2, 3.4, 4.2.2 |
| **Lệnh (tab `may1`)** | `bash ~/src/demo/cau06.sh` |
| **Thời gian** | 1 phút |
| **Web** | `localhost:18080` → bấm vào app mới nhất → **Jobs**: các action; **Stages**: shuffle; **Storage**: DataFrame được cache; **SQL**: kế hoạch thực thi |

**Nói:**
- **Pipeline:** 7 transformation, 9 action; dùng cache nhanh hơn **1,56 lần**.
- **Vùng curated:** Parquet chia phân vùng year/month/category (114 phân vùng).
- **Kết quả phân tích:** **64** sản phẩm tăng trưởng nhanh (3 tháng cuối so với 3 tháng liền trước); **369** khách có nguy cơ rời bỏ (HIGH và MEDIUM, theo RFM).

---

## Câu 7 – HBase (Quốc)

| | |
|---|---|
| **Báo cáo** | Mục 3.2.2, 3.6 |
| **Lệnh (tab `may1`)** | `bash ~/src/demo/cau07.sh` |
| **Thời gian** | 1,5 phút |
| **Web** | `localhost:16010` → mục **Tables** → `btl:customer_orders` → thấy **6 region** chia đều cho 3 RegionServer |

**Nói:**
- **Rowkey `customer_id#reverse_timestamp`:** đơn của cùng một khách nằm liền nhau, đơn mới nhất lên đầu. Một lần scan theo tiền tố là lấy được N đơn mới nhất.
- **3 column family:** `o` (đơn), `m` (tiền), `d` (giao hàng, giữ 5 phiên bản, nên xem được lịch sử trạng thái PLACED → DELIVERED → RETURNED).
- **Nén:** SNAPPY + FAST_DIFF nhỏ hơn **5,79 lần** so với không nén.

---

## Câu 8 – Dashboard theo quy trình BigSheets (Quyết)

| | |
|---|---|
| **Báo cáo** | Mục 4.3, Phụ lục C |
| **Web** | `localhost:8787` (RStudio) |
| **Thời gian** | 1 phút |

**Các bước:**
1. Ô **Files** (dưới phải) → `src` → `cau08_bigsheets` → bấm `dashboard.R` để mở code.
2. Bấm vào ô **Console** (dưới trái), dán lệnh rồi Enter:
   ```r
   setwd("~/src/cau08_bigsheets"); source("dashboard.R")
   ```
3. Ô **Files** → `output` → `hinh` → bấm `cau08-dashboard.png` để mở dashboard.

**Nói:**
- **Các bước BigSheets:** Workbook → Filter → Join → Group → Chart, làm lại bằng R vì không có IBM BigSheets.
- **Nội dung dashboard:** doanh thu, tỷ lệ trả và thời gian giao theo danh mục và tỉnh.

---

## Câu 9 – R + SQLite (Quyết)

| | |
|---|---|
| **Báo cáo** | Mục 4.2, 4.3 |
| **Web** | `localhost:8787` (RStudio) |
| **Thời gian** | 1 phút |

**Các bước:**
1. Ô **Files** → `src` → `cau09_r` → bấm `phan_tich.R` để mở code.
2. Ô **Console**, dán lệnh rồi Enter:
   ```r
   setwd("~/src/cau09_r"); source("phan_tich.R")
   ```
3. Ô **Files** → `output` → `hinh` → mở `cau09-hoi-quy-phan-du.png` và `cau09-roc.png`.
4. Ô **Files** → `output` → bấm `hoi_quy_so_sanh.csv` → **View File** để xem bảng so sánh mô hình.

**Nói:**
- **Quy trình:** kết nối SQLite, truy vấn SQL, xử lý bằng dplyr, vẽ bằng ggplot2, rồi ghi kết quả lại vào CSDL.
- **Hồi quy doanh thu:** R² test = **0,833**.
- **Phân loại trả hàng:**
  - AUC = **0,49**, ngang mô hình cơ sở.
  - Kiểm định χ² cho thấy tỷ lệ trả gần như đều ở mọi nhóm (p > 0,12), tức dữ liệu không có tín hiệu để dự đoán.
  - Nhóm báo cáo trung thực kết quả này.

---

## Câu 10 – Đối chiếu và khuyến nghị (Hiếu)

| | |
|---|---|
| **Báo cáo** | Mục 4.5, Chương 5 |
| **Lệnh (tab `may1`)** | `bash ~/src/demo/cau10.sh` |
| **Thời gian** | 10 giây |
| **Web** | Không cần |

**Nói:**
- **Cùng kết quả:** Pig, MapReduce và Spark viết độc lập nhưng cho cùng tệp kết quả. Mã md5 giống hệt, **0 ô sai khác** trên 114 ô.
- **Thời gian chạy:** MapReduce khoảng 18 s, Spark khoảng 20 s, Pig khoảng 63 s. Với dữ liệu nhỏ, thời gian khởi động job chiếm gần hết.
- **Khuyến nghị:** lật báo cáo Chương 5 để trình bày 7 khuyến nghị.

---

## Khi có sự cố

| Hiện tượng | Xử lý (tab `may1`) |
|---|---|
| Lệnh `hdfs`/`yarn` treo hoặc báo Connection refused | `start-cluster.sh` rồi `smoke-test.sh` |
| HBase báo "Master is initializing" kéo dài | `hbase-reset.sh`, rồi chạy lại Câu 2 và Câu 7 |
| Trang web không mở được | Bấm F5; nếu vẫn lỗi thì chạy `start-cluster.sh` |
| Máy chậm hoặc hết giờ | Thêm `nhanh` sau lệnh |
| Tab ssh bị đóng | Nhấp đúp lại `scripts\mo-terminal.cmd` |
| Máy hỏng hẳn | Trình bày bằng ảnh chụp trong Phụ lục C và các bảng kết quả trong báo cáo |
