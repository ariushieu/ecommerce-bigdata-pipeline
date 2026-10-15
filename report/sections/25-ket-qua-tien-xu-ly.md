## 2.5. Kết quả sau tiền xử lý

Bảng `orders` ở vùng curated (mục 2.4.2) được đọc lại để kiểm tra (`src/cau06_spark/output/pipeline_log.txt`).

*[Bảng:c06-so-ban-ghi]. Số bản ghi qua các bước tiền xử lý*

| Bước | Số bản ghi |
|---|---:|
| `orders.csv` ở vùng raw (0 dòng lỗi) | 15.000 |
| Bỏ OUTLIER / DUPLICATE / LATE | −297 / −149 / −146 |
| **Sau làm sạch** (14.095 OK, 313 MISSING) | **14.408** |
| Sau join danh mục; đọc lại từ curated | 14.408 |

**Nhận xét [Bảng:c06-so-ban-ghi]:** số đơn sạch, doanh thu ròng 78.218.341,22 và 1.114 đơn trả khớp profiling Câu 1 và Pig, MapReduce (mục 4.5); join `left` không làm mất hay nhân bản đơn nào.

Bảng curated có 45 cột (21 cột gốc, 24 cột mới; schema ở [Bảng:c06-schema-curated]), phân vùng theo `year`, `month`, `category` nên truy vấn lọc theo chúng chỉ đọc đúng phân vùng.

*[Bảng:c06-bien-moi]. Thống kê các biến mới tạo*

| Biến mới | Kết quả trên 14.408 đơn |
|---|---|
| `has_review` | 9.215 có; 5.193 NULL |
| `has_campaign` | 14.243 có; 165 NULL (đều là MISSING) |
| `seen_in_stream` | 4.793 đơn (33,3%) |
| `ship_to_home` | 808 đơn (5,61%) |
| `tenure_days` | 6 – 2.068 ngày, trung bình 1.057,1 |

**Nhận xét [Bảng:c06-bien-moi]:** tỷ lệ `ship_to_home` khớp khảo sát ở mục 2.3; 4.793 = 5.000 sự kiện trừ 207 sự kiện của đơn bị loại; thâm niên tối thiểu 6 ngày xác nhận mọi đơn đặt sau ngày đăng ký.
