## 4.5. Thảo luận kết quả

### 4.5.1. Đối chiếu kết quả Pig – MapReduce – Spark

Ba công cụ cùng tính số đơn, doanh thu ròng, số đơn trả và tỷ lệ trả theo danh mục × tháng trên cùng bản chụp dữ liệu và quy tắc làm sạch. Script `src/cau10_doi_chieu/compare.py` so từng ô của ba tệp `compare_category_month.csv` và so tổng với profiling của Câu 1, chạy tự động trong CI.

*[Bảng:c10-doi-chieu-ket-qua]. Đối chiếu kết quả danh mục × tháng của ba công cụ (`src/cau10_doi_chieu/output/doi_chieu.md`)*

| Công cụ | Số ô | Tổng đơn | Tổng doanh thu | Tổng đơn trả | Khớp Câu 1 | Giống từng byte với Pig |
|---|---:|---:|---:|---:|---|---|
| Pig | 114 | 14.408 | 78.218.341,22 | 1.114 | có | – |
| MapReduce | 114 | 14.408 | 78.218.341,22 | 1.114 | có | có |
| Spark | 114 | 14.408 | 78.218.341,22 | 1.114 | có | có |

**Nhận xét [Bảng:c10-doi-chieu-ket-qua]:**
- Cả 114 ô (6 danh mục × 19 tháng) trùng tuyệt đối, kể cả định dạng số, dù ba cài đặt được viết độc lập bằng ba mô hình lập trình khác nhau; đây là bằng chứng mạnh nhất cho tính đúng. Ở quy mô ×10, ba công cụ cũng cho 144.080 đơn, doanh thu 782.183.412,20, đúng bằng 10 lần.
- Để khớp từng byte, nhóm phải thống nhất cộng tiền bằng số nguyên xu hoặc DECIMAL, làm tròn HALF_UP và luôn ghi 2 chữ số thập phân.

### 4.5.2. Đối chiếu hiệu năng và độ phức tạp

Cùng phép tính được viết tối giản cho cả ba công cụ (`src/cau10_doi_chieu/`), chạy lần lượt trên cụm **không có ứng dụng YARN nào khác**, mỗi công cụ 3 lần, ở quy mô ×1 (2,3 MB) và ×10 (khoảng 23 MB). Thời gian đo tính từ lúc gõ lệnh tới khi kết quả nằm trên HDFS.

*[Bảng:c10-hieu-nang]. Cùng một phép tính danh mục × tháng bằng ba công cụ (`src/cau10_doi_chieu/output/bench.tsv`; trung vị và khoảng của 3 lần)*

| Công cụ | Số dòng mã | Job MapReduce | ×1 (15.000 đơn) | ×10 (150.000 đơn) |
|---|---:|---:|---:|---:|
| MapReduce (Java) | 296 (7 lớp, gồm cả mức tỉnh) | 1 | **18,1 s** (16,0–26,4) | **16,3 s** (15,5–16,4) |
| Spark (PySpark, DataFrame + SQL) | khoảng 60 (gồm hàm làm sạch dùng chung) | – (1 ứng dụng Spark) | 19,5 s (19,0–22,3) | 17,6 s (15,8–24,2) |
| Pig Latin | 19 | 3 | 64,1 s (59,5–64,9) | 54,1 s (53,9–55,3) |

**Nhận xét [Bảng:c10-hieu-nang]:**
- **Thời gian gần như không phụ thuộc lượng dữ liệu:** 23 MB vẫn nằm trong một block 128 MB nên chỉ có một tác vụ map, và thời gian chủ yếu là chi phí khởi động trên YARN (mục 4.4). MapReduce và Spark ngang nhau (khoảng 16–20 s) vì đều chỉ một lượt đọc, một lần shuffle, một lần ghi.
- **Pig chậm nhất (khoảng 3 lần) dù mã ngắn nhất**, vì `ORDER ... BY` biên dịch thành 3 job MapReduce nối tiếp, mỗi job tốn khoảng 15–20 s khởi động.
- **Độ phức tạp ngược với tốc độ ở dữ liệu nhỏ:** Pig 19 dòng, Spark khoảng 60, MapReduce gần 300 dòng Java nhưng kiểm soát được từng bước (Combiner giảm 85,8% dữ liệu shuffle, mục 3.5). Lợi thế của Spark chỉ rõ khi pipeline nhiều bước và dữ liệu đủ lớn để chia nhiều block (mục 4.4).

*[Bảng:c10-chon-cong-cu]. Khuyến nghị chọn công cụ theo loại công việc, rút ra từ thực nghiệm*

| Loại công việc | Công cụ phù hợp | Căn cứ |
|---|---|---|
| ETL khai báo, làm sạch, ghép bảng; người viết không chuyên Java | Pig | 19 dòng; JOIN replicated, SPLIT, STORE sẵn có (mục 2.4.1) |
| Phép tổng hợp đơn lẻ, chạy định kỳ; cần kiểm soát shuffle | MapReduce | Nhanh nhất khi chỉ có 1 job (16–18 s) |
| Pipeline nhiều bước, phân tích lặp, kết hợp SQL | Spark | Một ứng dụng thay cho 6–8 job; cache nhanh hơn 1,56 lần (mục 4.4) |
| Tra cứu theo khóa, đọc/ghi ngẫu nhiên | HBase | Quét theo tiền tố `customer_id#` (mục 3.2.2) |
| Thu thập luồng không mất dữ liệu | Flume + FileChannel | Giao đủ 1.000/1.000 sự kiện sau khi agent bị tắt đột ngột; MemoryChannel mất cả 1.000 (mục 3.3) |

**Nhận xét [Bảng:c10-chon-cong-cu]:** không có công cụ nào tốt nhất cho mọi việc; kiến trúc ở mục 1.5 dùng mỗi công cụ ở đúng khâu mà thực nghiệm cho thấy nó có lợi thế.

### 4.5.3. Đối chiếu với mục tiêu của đề tài

*[Bảng:c10-muc-tieu]. Mức độ đạt các mục tiêu cụ thể đã đặt ở [Bảng:muc-tieu-cu-the]*

| # | Mục tiêu | Kết quả | Đánh giá |
|---|---|---|---|
| 1 | Phân tích 5V và chất lượng dữ liệu | 5V + Variability; 6 nhóm vấn đề, 10 yêu cầu tiền xử lý (mục 1.3, 2.3) | Đạt |
| 2 | Thu thập lô và luồng không mất dữ liệu | 5.000/5.000 sự kiện vào HDFS và HBase (mục 3.3) | Đạt |
| 3 | Lưu trữ phân tán, chịu hỏng 1 node | 4 vùng, `fsck` HEALTHY; tắt datanode3: 0 block mất, đủ lại 3 bản sao sau 196 s (mục 3.2.1) | Đạt |
| 4 | Làm sạch thống nhất | 15.000 → 14.408 đơn ở Pig, MapReduce, Spark, R | Đạt |
| 5 | Doanh thu, tỷ lệ trả; ba công cụ khớp nhau | 2.049 ô danh mục × tỉnh × tháng; 114 ô trùng từng byte | Đạt |
| 6 | Sản phẩm tăng trưởng nhanh, khách nguy cơ rời bỏ | 64 sản phẩm; 369 khách HIGH và MEDIUM | Đạt về quy trình; tín hiệu yếu (mục 4.2.2) |
| 7 | Truy cập ngẫu nhiên lịch sử đơn | `btl:customer_orders` 14.408 dòng, 6 region | Đạt |
| 8 | Dashboard tái tạo được | Hướng dẫn BigSheets 9 bước, 4 KPI + 5 biểu đồ (mục 4.3) | Đạt (BigSheets mô phỏng) |
| 9 | Hồi quy và phân loại | R² test 0,833; AUC test 0,493 | Hồi quy đạt; phân loại **chưa đạt** |
| 10 | Ít nhất 5 khuyến nghị có căn cứ | 7 khuyến nghị (mục 4.5.4) | Đạt |

**Nhận xét [Bảng:c10-muc-tieu]:**
- Các mục tiêu về **hệ thống** đều đạt và được kiểm chứng tự động. Mục tiêu **dự báo hoàn trả** chưa đạt do dữ liệu chứ không do mô hình: tỷ lệ trả 7,73% gần như đồng đều theo mọi chiều (χ² của mọi yếu tố có p > 0,12, mục 4.2.3). Nhóm báo cáo đúng như vậy thay vì dùng accuracy 92,35%, vốn chỉ bằng mức đoán "không trả" cho mọi đơn.

### 4.5.4. Khuyến nghị

*[Bảng:c10-khuyen-nghi]. Khuyến nghị theo ba mục tiêu doanh thu – hoàn trả – giao hàng*

| # | Khuyến nghị | Căn cứ từ dữ liệu | Mục tiêu |
|---|---|---|---|
| 1 | **Tăng giá trị giỏ hàng bằng combo và khuyến mại theo số lượng**, thay vì giảm giá sâu | Số lượng giải thích 55,2% biến thiên doanh thu đơn, giảm giá 2,5%; mỗi 10 điểm giảm giá làm doanh thu đơn giảm 11,25% mà không giảm tỷ lệ trả (p = 0,967) (mục 4.2.3, 4.2.4) | Doanh thu |
| 2 | **Ưu tiên Fashion cho chương trình giảm hoàn trả** (bảng size, ảnh thật), theo dõi tỷ lệ trả hằng tuần | Tỷ lệ trả cao nhất (8,50%), doanh thu tăng nhanh nhất (+27,6% 3 tháng cuối); chênh lệch chưa có ý nghĩa thống kê (mục 4.2.2) | Hoàn trả, doanh thu |
| 3 | **Thu thập lý do trả hàng** ngay trong sự kiện trả hàng | Với các trường hiện có, AUC 0,493, không hơn đoán ngẫu nhiên (mục 4.2.5) | Hoàn trả |
| 4 | **Cam kết giao trong 5 ngày, tập trung xử lý 7% đơn vượt ngưỡng**; không kỳ vọng giao nhanh hơn sẽ giảm hoàn trả | P90 = 5 ngày, 7,01% đơn > 5 ngày; đơn giao > 5 ngày trả 7,82%, đơn giao 0–2 ngày trả 7,80% (mục 4.2.3) | Giao hàng |
| 5 | **Chăm sóc lại 369 khách nguy cơ rời bỏ, bắt đầu từ VIP**, có nhóm đối chứng | VIP có tỷ lệ HIGH 13,71%, không thấp hơn khách New; số khách không mua 90 ngày (188) chưa vượt mức ngẫu nhiên (211) (mục 4.2.2) | Doanh thu |
| 6 | **Đo hiệu quả chiến dịch bằng thí nghiệm A/B** trước khi tăng ngân sách | Biến chiến dịch không có ý nghĩa trong hồi quy; dữ liệu không có nhóm đối chứng (mục 4.2.4) | Doanh thu |
| 7 | **Nâng chất lượng dữ liệu nguồn:** thêm `customer_id`, `product_id`, `quality_flag` vào `order_event`; chuẩn hóa ô trống thành NULL; rà soát giá sản phẩm | `payload` chỉ có 4/23 trường; ô trống `''` khiến điểm đánh giá TB bị tính sai thành 1,94 thay vì 3,03; 117/400 sản phẩm có giá niêm yết thấp hơn giá vốn (mục 2.3, 3.3, 4.2.1) | Cả ba |

**Nhận xét [Bảng:c10-khuyen-nghi]:**
- Khuyến nghị 1, 4 và 7 dựa trên phát hiện chắc chắn (hệ số hồi quy có ý nghĩa, phân bố thời gian giao, lỗi dữ liệu đếm được); khuyến nghị 2, 5 và 6 dựa trên tín hiệu yếu nên được đề xuất dưới dạng **thí điểm có đo lường**.
- Khuyến nghị 3 thừa nhận giới hạn của dữ liệu: muốn giảm hoàn trả phải thu thêm thông tin, không chỉ phân tích sâu hơn trường hiện có.
