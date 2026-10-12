### 2.4.1. Làm sạch bằng Pig (vùng staging)

Kịch bản `src/cau04_pig/cau04.pig` đọc bản chụp raw `ingest_date=2026-08-01`, thực hiện các yêu cầu 1, 2, 3, 5, 6 và 9 của [Bảng:yeu-cau-tien-xu-ly] rồi ghi vùng **staging** `/btl/staging/orders` (số liệu từ `output/checks.tsv`).

*[Bảng:c04-buoc-lam-sach]. Các bước làm sạch bằng Pig và số bản ghi sau từng bước*

| # | Bước | Toán tử | Xử lý | Số bản ghi |
|---|---|---|---|---:|
| 1 | Đọc | LOAD `PigStorage(',')` | Khai báo kiểu 23 cột; ô trống, sai kiểu số → NULL | 15.001 dòng |
| 2 | Gắn trạng thái | FOREACH | `HEADER` (dòng tiêu đề có BOM); `INVALID` (thiếu khóa, sai kiểu, nhãn lạ) | HEADER 1, INVALID 0 |
| 3 | Lọc | FILTER | Bỏ `HEADER`, `INVALID` | 15.000 |
| 4 | Tách theo nhãn | SPLIT … OTHERWISE | Giữ OK (14.095) + MISSING (313); loại OUTLIER, DUPLICATE, LATE | giữ **14.408** / loại 592 |
| 5 | Chuẩn hóa | FOREACH | `review_score` trống giữ NULL; `campaign_id` trống → `NONE`; thêm `order_month` | 14.408 |
| 6 | Ghi staging | STORE `PigStorage('\t', '-schema')` | TSV, không tiêu đề, không BOM, LF | 14.408 dòng, 24 cột |
| 7 | Lưu bản ghi loại | STORE | `rejected_orders`, thêm cột `status` | 592 |
| 8 | Kiểm tra | DISTINCT, JOIN | DISTINCT 20 cột nội dung; JOIN với 2 bảng danh mục và với sự kiện | 15.000 → 15.000; 0 lệch; 5.000/5.000 khớp |

**Nhận xét [Bảng:c04-buoc-lam-sach]:**
- Còn **14.408 đơn** (quy ước §2); INVALID = 0 nên cả 592 bản ghi bị loại đều do nhãn chất lượng.
- Bước 8 xác nhận bằng Pig các phát hiện ở mục 2.3: DISTINCT không loại được dòng nào, và 321 sự kiện thuộc đơn bị loại không tự lọc được vì sự kiện không mang `quality_flag`.

*[Bảng:c04-truoc-sau]. Ví dụ dữ liệu trước (raw CSV) và sau (staging TSV) khi làm sạch, chỉ trích các cột có thay đổi*

| Bản ghi | Vùng | `review_score` | `campaign_id` | `quality_flag` | `order_month` | Kết quả |
|---|---|---|---|---|---|---|
| Dòng tiêu đề | raw | – | – | – | – | Có BOM → `HEADER`, bị loại |
| `ORD0000001` | raw | `4` | `CP018` | OK | – | Kết thúc bằng `\r\n` |
| | staging | `4` | `CP018` | OK | `2026-01` | Giữ, tách bằng tab |
| `ORD0000174` | raw | *(trống)* | *(trống)* | MISSING | – | |
| | staging | *(NULL)* | `NONE` | MISSING | `2025-08` | Giữ, chuẩn hóa ô trống |
| `ORD0000025` | raw | *(trống)* | `CP021` | OUTLIER | – | Sang `rejected_orders` |

**Nhận xét [Bảng:c04-truoc-sau]:**
- Ba cách: giữ (OK), giữ và chuẩn hóa ô trống (MISSING), loại (OUTLIER). `review_score` trống đọc lại là NULL nên AVG điểm đánh giá chỉ tính trên đơn có chấm điểm.
- `\r` của CRLF bị Hadoop cắt khi đọc. Staging chiếm 2.305.874 byte, xấp xỉ tệp gốc 2.298.806 byte.
