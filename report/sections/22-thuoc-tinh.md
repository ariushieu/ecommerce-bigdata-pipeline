## 2.2. Mô tả các thuộc tính

Cột *Kiểu* là kiểu nhóm chốt sau khảo sát (`data_dictionary.csv` chỉ ghi `TEXT/NUMERIC`).

*[Bảng:thuoc-tinh-orders]. Thuộc tính của `orders.csv` / `fact_main` (dữ liệu có cấu trúc)*

| Thuộc tính | Kiểu | Ý nghĩa | Ghi chú |
|---|---|---|---|
| `record_id` | STRING | Khóa kỹ thuật | Luôn bằng `order_id` |
| `timestamp` | TIMESTAMP (ISO 8601) | Thời điểm phát sinh đơn | Phân vùng năm/tháng, cửa sổ thời gian |
| `province` | STRING (18) | Tỉnh/thành phố | Là **tỉnh giao hàng** (khác tỉnh cư trú ở 94,4% đơn) |
| `source_system`, `ingest_mode`, `data_format` | STRING (5), (2), (3) | Hệ thống sinh, chế độ nạp, định dạng gốc | web, mobile, api, partner, batch; stream 62%, batch 38%; CSV, JSON, LOG |
| `order_id` | STRING | Mã đơn hàng | Khóa chính; không tăng theo thời gian |
| `customer_id`, `product_id` | STRING | Mã khách hàng, mã sản phẩm | Khóa ngoại → `customers` (1.200 giá trị), `products` (400 giá trị) |
| `category` | STRING (6) | Nhóm sản phẩm | Khớp 100% với `products` |
| `customer_segment` | STRING (4) | Phân khúc khách hàng | New, Regular, Loyal, VIP |
| `sales_channel` | STRING (3) | Kênh bán | mobile, web, marketplace |
| `quantity` | INT | Số lượng | 1–6 |
| `unit_price` | DOUBLE | Đơn giá | Đơn sạch 162,65 – 3.499,94 |
| `discount_rate`, `shipping_fee` | DOUBLE | Tỷ lệ giảm giá, phí giao hàng | 6 mức từ 0 đến 0,3; 5 mức từ 0 đến 50 |
| `net_revenue` | DOUBLE | Doanh thu ròng | **Mục tiêu doanh thu**; = `quantity × unit_price × (1 − discount_rate) + shipping_fee` |
| `payment_method` | STRING (4) | Phương thức thanh toán | COD, card, e_wallet, bank_transfer |
| `delivery_days` | INT (đọc dạng DOUBLE) | Số ngày giao | **Mục tiêu giao hàng**; đơn sạch 0–9 |
| `returned_flag` | INT (0/1) | Cờ trả hàng | **Mục tiêu hoàn trả**; nhãn phân loại |
| `review_score` | INT (1–5), cho phép rỗng | Điểm đánh giá | Rỗng 35,93% |
| `campaign_id` | STRING, cho phép rỗng | Mã chiến dịch | 30 chiến dịch; rỗng 1,1% |
| `quality_flag` | STRING (5) | Nhãn chất lượng | OK, MISSING, OUTLIER, LATE, DUPLICATE |

**Nhận xét [Bảng:thuoc-tinh-orders]:** 23 thuộc tính gồm khóa, thời gian, 6 chiều phân tích, 5 độ đo, 3 kết quả vận hành ứng với ba mục tiêu, 3 siêu dữ liệu nguồn và nhãn `quality_flag`.

*[Bảng:thuoc-tinh-events]. Thuộc tính của `events_stream.jsonl` (dữ liệu bán cấu trúc, luồng)*

| Thuộc tính | Kiểu | Ý nghĩa | Ghi chú |
|---|---|---|---|
| `event_id` | STRING | Mã sự kiện | = `EVT-` + `order_id`, dùng khử trùng lặp |
| `event_time` | TIMESTAMP (ISO 8601) | Thời điểm phát sinh | Mốc gom cửa sổ; 50,27% cặp liên tiếp sai thứ tự |
| `event_type` | STRING | Loại sự kiện | Chỉ có `order_event` |
| `source` | STRING (5) | Nguồn phát | Trùng `source_system` của đơn |
| `payload.category`, `payload.customer_segment` | STRING (6), (4) | Nhóm sản phẩm, phân khúc khách | Chiều phân tích luồng |
| `payload.net_revenue` | DOUBLE | Doanh thu ròng | Độ đo luồng |
| `payload.returned_flag` | INT (0/1) | Cờ trả hàng | Cảnh báo tỷ lệ trả |

**Nhận xét [Bảng:thuoc-tinh-events]:**
- Sự kiện gồm phần vỏ ổn định và `payload` lồng chỉ mang 4/23 thuộc tính của đơn; phân tích cần tỉnh, sản phẩm hay số ngày giao phải ghép với `orders`, nên thuộc nhánh tĩnh.

*[Bảng:thuoc-tinh-customers]. Thuộc tính của `customers.csv` / `entity_master` (dữ liệu có cấu trúc, danh mục)*

| Thuộc tính | Kiểu | Ý nghĩa | Ghi chú |
|---|---|---|---|
| `customer_id` | STRING | Mã khách hàng | Khóa chính |
| `customer_segment` | STRING (4) | Phân khúc | |
| `age_group`, `gender` | STRING (5), (3) | Nhóm tuổi, giới tính | 18-24 … 55+; M, F, Other |
| `province` | STRING (18) | Tỉnh cư trú | Khác tỉnh giao hàng của đơn |
| `join_date` | DATE | Ngày tham gia | 25/11/2020 – 31/12/2024 |
| `loyalty_score` | INT (0–100) | Điểm trung thành | Đặc trưng mô hình rời bỏ |
| `preferred_channel` | STRING (2) | Kênh ưa thích | web, mobile |

*[Bảng:thuoc-tinh-products]. Thuộc tính của `products.csv` / `item_master` (dữ liệu có cấu trúc, danh mục)*

| Thuộc tính | Kiểu | Ý nghĩa | Ghi chú |
|---|---|---|---|
| `product_id` | STRING | Mã sản phẩm | Khóa chính |
| `category` | STRING (6) | Nhóm sản phẩm | |
| `brand`, `supplier_id` | STRING (44), (79) | Thương hiệu, nhà cung cấp | |
| `unit_cost` | DOUBLE | Giá vốn | 22,71 – 1.798,04 |
| `list_price` | DOUBLE | Giá niêm yết | 49,53 – 3.191,09; thấp hơn giá vốn ở 117 sản phẩm |
| `rating` | DOUBLE (2,5–5,0) | Điểm sản phẩm | |
| `active_flag` | INT (0/1) | Còn kinh doanh | 14 sản phẩm ngừng bán |

**Nhận xét [Bảng:thuoc-tinh-customers] và [Bảng:thuoc-tinh-products]:** hai bảng danh mục nhỏ (1.200 và 400 dòng), ít thay đổi, nên khi ghép với đơn hàng có thể gửi bản sao tới mọi node (*replicated join* trong Pig, *broadcast join* trong Spark) thay vì xáo trộn qua mạng.
