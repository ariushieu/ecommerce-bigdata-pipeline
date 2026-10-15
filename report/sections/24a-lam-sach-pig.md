### 2.4.1. Làm sạch bằng Pig (vùng staging)

Kịch bản `src/cau04_pig/cau04.pig` đọc bản chụp raw `ingest_date=2026-08-01`, thực hiện các yêu cầu 1, 2, 3, 5, 6 và 9 của [Bảng:yeu-cau-tien-xu-ly] rồi ghi vùng **staging** `/btl/staging/orders` (số liệu từ `output/checks.tsv`).

*[Bảng:c04-buoc-lam-sach]. Các bước làm sạch bằng Pig và số bản ghi sau từng bước*

| # | Toán tử | Xử lý | Số bản ghi |
|---|---|---|---:|
| 1 | LOAD `PigStorage(',')` | Khai báo kiểu 23 cột; ô trống, sai kiểu → NULL | 15.001 dòng |
| 2 | FOREACH + FILTER | Gắn và bỏ `HEADER`, `INVALID` | HEADER 1, INVALID 0 → 15.000 |
| 3 | SPLIT … OTHERWISE | Giữ OK (14.095) + MISSING (313); loại OUTLIER, DUPLICATE, LATE | giữ **14.408** / loại 592 |
| 4 | FOREACH | `campaign_id` trống → `NONE`; thêm `order_month` | 14.408 |
| 5 | STORE `PigStorage('\t', '-schema')` | Staging TSV 24 cột; bản ghi loại vào `rejected_orders` | 14.408 / 592 |
| 6 | DISTINCT, JOIN | Kiểm tra trùng 20 cột; JOIN với 2 bảng danh mục và sự kiện | 15.000 → 15.000; 0 lệch; 5.000/5.000 khớp |

**Nhận xét [Bảng:c04-buoc-lam-sach]:** INVALID = 0 nên cả 592 bản ghi bị loại đều do nhãn chất lượng. Bước 6 xác nhận phát hiện ở mục 2.3: DISTINCT không loại được dòng nào, và sự kiện không mang `quality_flag` nên không tự lọc được.

*[Bảng:c04-truoc-sau]. Ví dụ dữ liệu trước (raw CSV) và sau (staging TSV), chỉ trích các cột có thay đổi*

| Bản ghi | Vùng | `review_score` | `campaign_id` | `quality_flag` | `order_month` |
|---|---|---|---|---|---|
| `ORD0000174` | raw | *(trống)* | *(trống)* | MISSING | – |
| | staging | *(NULL)* | `NONE` | MISSING | `2025-08` |

**Nhận xét [Bảng:c04-truoc-sau]:** `review_score` NULL nên AVG điểm chỉ tính trên đơn có chấm điểm. `\r` của CRLF bị Hadoop cắt khi đọc; staging chiếm 2.305.874 byte, xấp xỉ tệp gốc 2.298.806 byte.
