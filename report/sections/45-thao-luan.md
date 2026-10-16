## 4.5. Thảo luận kết quả

### 4.5.1. Đối chiếu kết quả Pig – MapReduce – Spark

Ba công cụ cùng tính bảng danh mục × tháng trên cùng bản chụp dữ liệu; script `src/cau10_doi_chieu/compare.py` so từng ô của ba tệp `compare_category_month.csv` và so tổng với profiling Câu 1, chạy tự động trong CI.

*[Bảng:c10-doi-chieu-ket-qua]. Đối chiếu kết quả danh mục × tháng của ba công cụ (`src/cau10_doi_chieu/output/doi_chieu.md`)*

| Công cụ | Số ô | Tổng đơn | Tổng doanh thu | Tổng đơn trả | Khớp Câu 1 | Giống từng byte với Pig |
|---|---:|---:|---:|---:|---|---|
| Pig | 114 | 14.408 | 78.218.341,22 | 1.114 | có | – |
| MapReduce | 114 | 14.408 | 78.218.341,22 | 1.114 | có | có |
| Spark | 114 | 14.408 | 78.218.341,22 | 1.114 | có | có |

**Nhận xét [Bảng:c10-doi-chieu-ket-qua]:** cả 114 ô (6 danh mục × 19 tháng) trùng tuyệt đối dù viết độc lập bằng ba mô hình lập trình, nhờ thống nhất cộng tiền bằng số nguyên xu hoặc DECIMAL, làm tròn HALF_UP; đây là bằng chứng mạnh nhất cho tính đúng. Ở quy mô ×10, ba công cụ cũng cho 144.080 đơn, doanh thu 782.183.412,20.

### 4.5.2. Đối chiếu hiệu năng và độ phức tạp

Cùng phép tính chạy trên cụm **không có ứng dụng YARN nào khác**, mỗi công cụ 3 lần, ở quy mô ×1 (2,3 MB) và ×10 (khoảng 23 MB); thời gian tính tới khi kết quả nằm trên HDFS.

*[Bảng:c10-hieu-nang]. Cùng một phép tính danh mục × tháng bằng ba công cụ (`src/cau10_doi_chieu/output/bench.tsv`; trung vị và khoảng của 3 lần)*

| Công cụ | Số dòng mã | Job MapReduce | ×1 (15.000 đơn) | ×10 (150.000 đơn) |
|---|---:|---:|---:|---:|
| MapReduce (Java) | 296 | 1 | **18,1 s** (16,0–26,4) | **16,3 s** (15,5–16,4) |
| Spark (PySpark) | khoảng 60 | – | 19,5 s (19,0–22,3) | 17,6 s (15,8–24,2) |
| Pig Latin | 19 | 3 | 64,1 s (59,5–64,9) | 54,1 s (53,9–55,3) |

**Nhận xét [Bảng:c10-hieu-nang]:**
- Thời gian gần như không phụ thuộc lượng dữ liệu vì 23 MB vẫn nằm trong một block, chi phí chủ yếu là khởi động trên YARN (mục 4.4). **Pig chậm nhất dù mã ngắn nhất** vì `ORDER ... BY` sinh 3 job nối tiếp.
- Độ phức tạp ngược với tốc độ ở dữ liệu nhỏ: MapReduce gần 300 dòng Java nhưng kiểm soát được từng bước (Combiner giảm 85,8% dữ liệu shuffle, mục 3.5); lợi thế của Spark chỉ rõ khi pipeline nhiều bước và dữ liệu chia nhiều block.

Từ đó, nhóm dùng Pig cho ETL khai báo, MapReduce cho phép tổng hợp đơn lẻ chạy định kỳ, Spark cho pipeline nhiều bước, HBase cho tra cứu theo khóa và Flume + FileChannel cho thu thập luồng (giao đủ 1.000/1.000 sự kiện khi agent bị tắt đột ngột, mục 3.3), đúng như kiến trúc ở mục 1.5.

### 4.5.3. Đối chiếu với mục tiêu của đề tài

*[Bảng:c10-muc-tieu]. Mức độ đạt các mục tiêu cụ thể đã đặt ở [Bảng:muc-tieu-cu-the]*

| # | Kết quả | Đánh giá |
|---|---|---|
| 1 | 5V + Variability; 10 yêu cầu tiền xử lý (mục 1.3, 2.3) | Đạt |
| 2 | 5.000/5.000 sự kiện vào HDFS và HBase (mục 3.3) | Đạt |
| 3 | Tắt datanode3: 0 block mất, đủ lại 3 bản sao sau 196 s (mục 3.2.1) | Đạt |
| 4 | 15.000 → 14.408 đơn ở Pig, MapReduce, Spark, R | Đạt |
| 5 | 2.049 ô danh mục × tỉnh × tháng; 114 ô trùng từng byte | Đạt |
| 6 | 64 sản phẩm; 369 khách HIGH và MEDIUM | Đạt quy trình; tín hiệu yếu |
| 7 | `btl:customer_orders` 14.408 dòng, 6 region | Đạt |
| 8 | Hướng dẫn BigSheets 9 bước, 4 KPI + 5 biểu đồ (mục 4.3) | Đạt (mô phỏng) |
| 9 | R² test 0,833; AUC test 0,493 | Hồi quy đạt; phân loại **chưa đạt** |
| 10 | 7 khuyến nghị (mục 4.5.4) | Đạt |

**Nhận xét [Bảng:c10-muc-tieu]:** mục tiêu **hệ thống** đều đạt, kiểm chứng tự động. Mục tiêu dự báo hoàn trả chưa đạt do dữ liệu chứ không do mô hình: tỷ lệ trả gần như đồng đều theo mọi chiều (χ² của mọi yếu tố có p > 0,12, mục 4.2.3); accuracy 92,35% chỉ bằng mức đoán "không trả" cho mọi đơn nên không dùng làm thước đo.

### 4.5.4. Khuyến nghị

*[Bảng:c10-khuyen-nghi]. Khuyến nghị theo ba mục tiêu doanh thu – hoàn trả – giao hàng*

| # | Khuyến nghị | Căn cứ từ dữ liệu | Mục tiêu |
|---|---|---|---|
| 1 | **Tăng giá trị giỏ bằng combo, khuyến mại theo số lượng** thay vì giảm giá sâu | Số lượng giải thích 55,2% biến thiên doanh thu, giảm giá 2,5%; mỗi 10 điểm giảm giá làm doanh thu đơn giảm 11,25% mà không giảm tỷ lệ trả (p = 0,967) | Doanh thu |
| 2 | **Ưu tiên Fashion cho chương trình giảm hoàn trả**, theo dõi hằng tuần | Tỷ lệ trả cao nhất (8,50%), doanh thu tăng nhanh nhất (+27,6% 3 tháng cuối); chênh lệch chưa có ý nghĩa thống kê | Hoàn trả |
| 3 | **Thu thập lý do trả hàng** trong sự kiện trả | Trường hiện có chỉ cho AUC 0,493 (mục 4.2.5) | Hoàn trả |
| 4 | **Cam kết giao trong 5 ngày, xử lý 7% đơn vượt ngưỡng** | P90 = 5 ngày; đơn giao > 5 ngày trả 7,82%, 0–2 ngày trả 7,80%: giao nhanh hơn không giảm hoàn trả | Giao hàng |
| 5 | **Chăm sóc lại 369 khách nguy cơ rời bỏ, bắt đầu từ VIP**, có nhóm đối chứng | VIP có tỷ lệ HIGH 13,71%; 188 khách không mua 90 ngày, chưa vượt mức ngẫu nhiên (211) | Doanh thu |
| 6 | **Thí nghiệm A/B cho chiến dịch** trước khi tăng ngân sách | Biến chiến dịch không có ý nghĩa trong hồi quy (mục 4.2.4) | Doanh thu |
| 7 | **Nâng chất lượng dữ liệu nguồn:** thêm `customer_id`, `product_id`, `quality_flag` vào `order_event`; chuẩn hóa ô trống | `payload` chỉ có 4/23 trường; ô trống `''` làm điểm đánh giá TB sai thành 1,94 thay vì 3,03; 117/400 sản phẩm giá niêm yết dưới giá vốn | Cả ba |

**Nhận xét [Bảng:c10-khuyen-nghi]:** khuyến nghị 1, 4, 7 dựa trên phát hiện chắc chắn; 2, 5, 6 dựa trên tín hiệu yếu nên đề xuất dưới dạng **thí điểm có đo lường**; khuyến nghị 3 thừa nhận phải thu thêm dữ liệu.
