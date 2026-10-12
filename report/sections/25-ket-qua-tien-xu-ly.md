## 2.5. Kết quả sau tiền xử lý

Kết quả là bảng `orders` ở vùng curated (`/btl/curated/orders/`) do Spark ghi ở mục 2.4.2, đọc lại để kiểm tra (nguồn: `src/cau06_spark/output/pipeline_log.txt`, `pipeline_metrics.json`).

*[Bảng:c06-so-ban-ghi]. Số bản ghi qua các bước tiền xử lý*

| Bước | Số bản ghi | Ghi chú |
|---|---:|---|
| `orders.csv` ở vùng raw | 15.000 | 0 dòng lỗi |
| Bỏ OUTLIER / DUPLICATE / LATE | −297 / −149 / −146 | Loại theo nhãn |
| **Còn lại sau làm sạch** | **14.408** | 14.095 OK và 313 MISSING |
| Sau join `products`, `customers` | 14.408 | 0 đơn không khớp khóa |
| Đọc lại từ vùng curated (Parquet) | 14.408 | 114 phân vùng `year/month/category` |

**Nhận xét [Bảng:c06-so-ban-ghi]:**
- Số đơn sạch, tổng doanh thu ròng 78.218.341,22 và 1.114 đơn trả khớp với profiling của Câu 1 và với Pig, MapReduce (mục 4.5).
- Join `left` không làm mất hay nhân bản đơn nào, xác nhận toàn vẹn tham chiếu (mục 2.3).

Bảng curated có 45 cột: 21 cột gốc (bỏ `timestamp` vì đã thay bằng `order_ts`, bỏ `record_id` vì luôn bằng `order_id`) và 24 cột mới về thời gian, tiền, cờ, thông tin sản phẩm và khách hàng; `year`, `month`, `category` nằm trên đường dẫn thư mục nên truy vấn lọc theo chúng chỉ đọc đúng phân vùng (*partition pruning*). Schema đầy đủ ở Phụ lục B ([Bảng:c06-schema-curated]); dung lượng so với CSV gốc ở mục 4.1.4.

*[Bảng:c06-bien-moi]. Thống kê các biến mới tạo (đọc lại từ vùng curated)*

| Biến mới | Định nghĩa | Kết quả trên 14.408 đơn |
|---|---|---|
| `has_review` | `review_score` khác NULL | 9.215 có; 5.193 NULL |
| `has_campaign` | `campaign_id` khác NULL | 14.243 có; 165 NULL (đều là MISSING) |
| `seen_in_stream` | Mã đơn có trong `events_stream.jsonl` | 4.793 đơn (33,3%) |
| `ship_to_home` | Tỉnh giao hàng = tỉnh cư trú | 808 đơn (5,61%) |
| `product_active` | Từ `products.active_flag` | 497 đơn mua sản phẩm ngừng bán |
| `tenure_days` | Số ngày từ `join_date` tới ngày đặt | 6 – 2.068 ngày, trung bình 1.057,1 |

**Nhận xét [Bảng:c06-bien-moi]:**
- Chỉ 5,61% đơn giao về tỉnh cư trú, khớp khảo sát ở mục 2.3; 4.793 = 5.000 sự kiện trừ 207 sự kiện của đơn đã bị loại (mục 4.2.2).
- Thâm niên tối thiểu 6 ngày: mọi đơn đều đặt sau ngày khách đăng ký, thêm một kiểm tra nhất quán.
