## 2.2. Mô tả các thuộc tính

Cột *Kiểu* là kiểu nhóm chốt sau khảo sát (`data_dictionary.csv` chỉ ghi `TEXT/NUMERIC`).

*[Bảng:thuoc-tinh-orders]. Thuộc tính của `orders.csv` / `fact_main` (dữ liệu có cấu trúc)*

| Thuộc tính | Kiểu | Ý nghĩa | Ghi chú |
|---|---|---|---|
| `record_id`, `order_id` | STRING | Khóa kỹ thuật, mã đơn | Bằng nhau; không tăng theo thời gian |
| `timestamp` | TIMESTAMP | Thời điểm đặt đơn | Phân vùng năm/tháng |
| `province` | STRING (18) | Tỉnh/thành | **Tỉnh giao hàng** (khác tỉnh cư trú ở 94,4% đơn) |
| `source_system`, `ingest_mode`, `data_format` | STRING (5), (2), (3) | Siêu dữ liệu nguồn | stream 62%, batch 38% |
| `customer_id`, `product_id` | STRING | Khóa ngoại | → `customers`, `products` |
| `category`, `customer_segment`, `sales_channel` | STRING (6), (4), (3) | Danh mục, phân khúc, kênh bán | Chiều phân tích |
| `quantity` | INT | Số lượng | 1–6 |
| `unit_price` | DOUBLE | Đơn giá | Đơn sạch 162,65 – 3.499,94 |
| `discount_rate`, `shipping_fee` | DOUBLE | Giảm giá, phí giao | 6 mức 0–0,3; 5 mức 0–50 |
| `net_revenue` | DOUBLE | Doanh thu ròng | **Mục tiêu doanh thu**; = `quantity × unit_price × (1 − discount_rate) + shipping_fee` |
| `payment_method` | STRING (4) | Thanh toán | COD, card, e_wallet, bank_transfer |
| `delivery_days` | INT (đọc dạng DOUBLE) | Số ngày giao | **Mục tiêu giao hàng**; đơn sạch 0–9 |
| `returned_flag` | INT (0/1) | Cờ trả hàng | **Mục tiêu hoàn trả** |
| `review_score` | INT (1–5), cho phép rỗng | Điểm đánh giá | Rỗng 35,93% |
| `campaign_id` | STRING, cho phép rỗng | Mã chiến dịch | 30 chiến dịch; rỗng 1,1% |
| `quality_flag` | STRING (5) | Nhãn chất lượng | OK, MISSING, OUTLIER, LATE, DUPLICATE |

**Nhận xét [Bảng:thuoc-tinh-orders]:** 23 thuộc tính gồm khóa, thời gian, 6 chiều phân tích, 5 độ đo, 3 kết quả vận hành ứng với ba mục tiêu, 3 siêu dữ liệu nguồn và nhãn `quality_flag`.

*[Bảng:thuoc-tinh-events]. Thuộc tính của `events_stream.jsonl` (dữ liệu bán cấu trúc, luồng)*

| Thuộc tính | Kiểu | Ghi chú |
|---|---|---|
| `event_id` | STRING | = `EVT-` + `order_id`, dùng khử trùng lặp |
| `event_time` | TIMESTAMP | Mốc gom cửa sổ; 50,27% cặp liên tiếp sai thứ tự |
| `event_type`, `source` | STRING | Chỉ có `order_event`; `source` trùng `source_system` |
| `payload.category`, `payload.customer_segment` | STRING (6), (4) | Chiều phân tích luồng |
| `payload.net_revenue` | DOUBLE | Độ đo luồng |
| `payload.returned_flag` | INT (0/1) | Cảnh báo tỷ lệ trả |

**Nhận xét [Bảng:thuoc-tinh-events]:** `payload` lồng chỉ mang 4/23 thuộc tính của đơn; phân tích cần tỉnh, sản phẩm hay số ngày giao phải ghép với `orders` nên thuộc nhánh tĩnh.

*[Bảng:thuoc-tinh-customers]. Thuộc tính của hai bảng danh mục `customers.csv` / `entity_master` và `products.csv` / `item_master`*

| Bảng | Thuộc tính (kiểu) | Ghi chú |
|---|---|---|
| customers (1.200 dòng) | `customer_id` (khóa), `customer_segment`, `age_group`, `gender`, `province` (STRING); `join_date` (DATE); `loyalty_score` (INT 0–100); `preferred_channel` (STRING) | `province` là tỉnh cư trú; `join_date` 25/11/2020 – 31/12/2024 |
| products (400 dòng) | `product_id` (khóa), `category`, `brand`, `supplier_id` (STRING); `unit_cost`, `list_price`, `rating` (DOUBLE); `active_flag` (INT 0/1) | `list_price` thấp hơn giá vốn ở 117 sản phẩm; 14 sản phẩm ngừng bán |

**Nhận xét [Bảng:thuoc-tinh-customers]:** hai bảng danh mục nhỏ, ít thay đổi, nên khi ghép với đơn hàng có thể gửi bản sao tới mọi node (*replicated join* trong Pig, *broadcast join* trong Spark) thay vì xáo trộn qua mạng.
