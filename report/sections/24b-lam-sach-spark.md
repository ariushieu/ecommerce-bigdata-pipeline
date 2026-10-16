### 2.4.2. Làm sạch và biến đổi bằng Spark (vùng curated)

Spark đọc bản chụp `ingest_date=2026-08-01` ở vùng raw, thực hiện các yêu cầu ở [Bảng:yeu-cau-tien-xu-ly] và ghi vào `/btl/curated/orders/` (mục 3.2). Mã nguồn: `src/cau06_spark/pipeline.py` (hàm `clean_orders`, `enrich`); số liệu từ `output/pipeline_log.txt`.

*[Bảng:c06-buoc-lam-sach]. Các bước làm sạch và biến đổi trong Spark*

| # | Bước | Cách làm trong Spark | Kết quả |
|---|---|---|---|
| 1 | Đọc nguồn | CSV với schema 23 cột, `mode="FAILFAST"`; JSON Lines | 15.000 đơn, 0 dòng lỗi; 5.000 sự kiện |
| 2 | Lọc theo nhãn | `filter(~isin("OUTLIER","DUPLICATE","LATE"))` | Giữ 313 MISSING; còn **14.408** |
| 3 | Ô trống thành NULL | `when(trim(c) == "", NULL)` | Không thay bằng 0; cờ `has_review`, `has_campaign` |
| 4 | Chốt kiểu, tạo cột | `to_timestamp`; `delivery_days` → INT; `ym`, `month_idx`, `gross_amount`… | Phục vụ phân vùng và chuỗi 19 tháng |
| 5 | Join danh mục | `broadcast(products)`, `broadcast(customers)`, `left` | 0 đơn không khớp |
| 6 | Đối chiếu luồng | Bỏ tiền tố `EVT-`, `distinct`, join `left` | Cờ `seen_in_stream`; **không cộng** doanh thu sự kiện |
| 7 | Cột suy diễn | `ship_to_home`, `tenure_days` | Làm rõ `province` là tỉnh giao hàng |
| 8 | Ghi curated | `partitionBy("year","month","category").parquet` | 114 phân vùng, mỗi phân vùng 1 tệp |

**Nhận xét [Bảng:c06-buoc-lam-sach]:** mọi bước nằm trong **một** DataFrame pipeline, không ghi trung gian xuống HDFS; hai danh mục chỉ 1.200 và 400 dòng nên được **broadcast**, tương đương replicated join của Pig (mục 2.4.1). Ví dụ hai đơn trước và sau xử lý ở Phụ lục B ([Bảng:c06-truoc-sau]).
