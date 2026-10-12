### 2.4.2. Làm sạch và biến đổi bằng Spark (vùng curated)

Spark đọc bản chụp `ingest_date=2026-08-01` ở vùng raw, thực hiện các yêu cầu ở [Bảng:yeu-cau-tien-xu-ly] và ghi vào `/btl/curated/orders/` (mục 3.2). Mã nguồn: `src/cau06_spark/pipeline.py` (hàm `clean_orders`, `enrich`); số liệu từ `output/pipeline_log.txt`.

*[Bảng:c06-buoc-lam-sach]. Các bước làm sạch và biến đổi trong Spark*

| # | Bước | Cách làm trong Spark | Kết quả |
|---|---|---|---|
| 1 | Đọc nguồn | CSV với schema tường minh 23 cột, `mode="FAILFAST"`; JSON Lines với `payload` kiểu `STRUCT` | 15.000 đơn, 0 dòng lỗi, BOM tự bị bỏ; 5.000 sự kiện |
| 2 | Lọc theo nhãn | `upper(trim(quality_flag))`, `filter(~isin("OUTLIER","DUPLICATE","LATE"))` | Bỏ 592 đơn, giữ 313 MISSING; còn **14.408** |
| 3 | Ô trống thành NULL | `review_score` rỗng tự thành NULL; `campaign_id` qua `when(trim(c) == "", NULL)` | Không thay bằng 0; thêm cờ `has_review`, `has_campaign` |
| 4 | Chốt kiểu, tạo cột | `to_timestamp`; `delivery_days` → INT; `ym`, `month_idx`, `hour`; `gross_amount`, `discount_amount` | Phục vụ phân vùng và chuỗi 19 tháng |
| 5 | Join danh mục | `broadcast(products)`, `broadcast(customers)`, kiểu `left` | 0 đơn không khớp |
| 6 | Đối chiếu luồng | `regexp_replace(event_id, "^EVT-", "")`, `distinct`, join `left` | Cờ `seen_in_stream`; **không cộng** doanh thu sự kiện |
| 7 | Cột suy diễn | `ship_to_home`, `tenure_days = datediff(...)` | Làm rõ `province` là tỉnh giao hàng |
| 8 | Ghi curated | `repartition` + `partitionBy("year","month","category").parquet` | 114 phân vùng, mỗi phân vùng 1 tệp (Snappy) |

**Nhận xét [Bảng:c06-buoc-lam-sach]:**
- Mọi bước nằm trong **một** DataFrame pipeline; Catalyst gộp nhánh đơn hàng vào một stage, không ghi trung gian xuống HDFS.
- Hai danh mục chỉ 1.200 và 400 dòng nên được **broadcast**, tương đương replicated join của Pig (mục 2.4.1).

*[Bảng:c06-truoc-sau]. Ví dụ hai đơn trước và sau xử lý (trích `pipeline_log.txt`)*

| Trường | ORD0000002 – trước | ORD0000002 – sau | ORD0000014 – sau |
|---|---|---|---|
| Thời điểm | `2025-10-12T22:41:50` (chuỗi) | `2025-10-12 22:41:50` (TIMESTAMP) | `2025-01-20 07:52:06` |
| `ym` / `month_idx` | – | `2025-10` / 9 | `2025-01` / 0 |
| `delivery_days` | `3.0` (DOUBLE) | `3` (INT) | `3` |
| `review_score` / `has_review` | rỗng | NULL / false | 2 / true |
| `brand` / `home_province` | – | Brand-40 / Hai Phong | Brand-25 / Da Nang |
| `seen_in_stream` | – | true | true |

**Nhận xét [Bảng:c06-truoc-sau]:** `review_score` rỗng được giữ là NULL nên không kéo thấp điểm trung bình; `home_province` của ORD0000002 (Hai Phong) khác tỉnh giao hàng (Lam Dong).
