## 4.1. Kết quả xử lý

Mục này trình bày kết quả tiêu biểu của Pig (Câu 4), MapReduce (Câu 5) và Spark (Câu 6) trên **14.408 đơn sạch** của bản chụp `ingest_date=2026-08-01`, lấy từ HDFS (`src/cau04_pig/output/`, `src/cau05_mapreduce/output/`).

### 4.1.1. Kết quả Pig (Câu 4)

*[Bảng:c04-kq-danh-muc]. Tổng hợp theo danh mục sau JOIN với `customers`, `products` (`category_summary.tsv`)*

| Danh mục | Đơn | Khách hàng khác nhau | Doanh thu ròng | Đơn trả | Tỷ lệ trả (%) |
|---|---:|---:|---:|---:|---:|
| Books | 2.953 | 1.108 | 15.741.983,83 | 224 | 7,59 |
| Home | 2.616 | 1.072 | 14.257.300,58 | 196 | 7,49 |
| Electronics | 2.505 | 1.042 | 14.086.726,93 | 189 | 7,54 |
| Sports | 2.280 | 1.002 | 12.994.254,03 | 180 | 7,89 |
| Beauty | 2.219 | 1.033 | 11.426.625,74 | 169 | 7,62 |
| Fashion | 1.835 | 936 | 9.711.450,11 | 156 | 8,50 |

**Nhận xét [Bảng:c04-kq-danh-muc]:** Mọi chỉ số **trùng khớp** profiling ở Câu 1, nên làm sạch và JOIN không làm mất hay nhân bản đơn nào. Books dẫn đầu về đơn và doanh thu; Fashion thấp nhất nhưng tỷ lệ trả cao nhất (8,50%).

Kết quả GROUP BY danh mục × phân khúc ([Bảng:c04-kq-phan-khuc], Phụ lục B) có 24 nhóm 412–772 đơn; giá trị đơn trung bình chỉ dao động 4.936,51–5.829,41 nên chênh lệch doanh thu chủ yếu do **số đơn**, và tỷ lệ trả từng nhóm trùng ma trận R ở [Bảng:c09-ma-tran-tra]. Top 10 sản phẩm (`top10_products.tsv`) dẫn đầu là P0310 (Books, 502.072,27); Home chiếm 6/10.

Kịch bản sinh **17 job** MapReduce, mất 339,1 s từ lúc gọi `pig`; 17 job chỉ **chạy** tổng 129,0 s (mỗi job 4,2–9,1 s), còn tổng thời gian **chờ** YARN cấp container là 479,9 s do các nhánh độc lập được nộp cùng lúc và trùng job Spark của Câu 6 (`runtime.txt`). Với dữ liệu nhỏ cần **giảm số job**: bản đầu 26 job mất 583,9 s (mục 3.5.1).

### 4.1.2. Kết quả MapReduce (Câu 5)

Kết quả `category_province_month.tsv` có **2.049 dòng** trên 2.052 bộ (danh mục, tỉnh, tháng) có thể có. Gộp theo tỉnh ([Bảng:c05-kq-tinh], Phụ lục B), doanh thu chênh khoảng 22% giữa Can Tho và Khanh Hoa, tỷ lệ trả 5,87–9,11% nhưng kiểm định χ² cho p = 0,553 ([Bảng:c09-kiem-dinh]) nên **chưa đủ căn cứ** coi là khác biệt thật. Ở mức ô, 1.190/2.049 ô (58,1%) không có đơn trả, nên ra quyết định ở mức gộp.

*[Bảng:c05-counter]. Counter của job chính có và không có Combiner (`counters_*.txt`, `bench.tsv`)*

| Counter | Có Combiner | Không Combiner |
|---|---:|---:|
| Map input / output records | 15.001 / 14.408 | 15.001 / 14.408 |
| Combine input / output records | 14.408 / 2.049 | 0 / 0 |
| Reduce input records | 2.049 | 14.408 |
| Reduce shuffle bytes | 105.658 | 742.292 |
| Thời gian job, trung bình 3 lần | 14,6 s | 16,2 s |

**Nhận xét [Bảng:c05-counter]:** Combiner giảm số bản ghi qua shuffle **7 lần** và số byte shuffle **85,8%**, hai đầu ra giống hệt (`diff`); thời gian chỉ giảm khoảng 1,5 s vì chi phí khởi động chiếm phần lớn. Counter của Mapper khớp Câu 1 (bỏ 1 tiêu đề, 592 bản ghi theo nhãn, không có `MALFORMED`).

### 4.1.3. Đối chiếu Pig – MapReduce

Tệp `compare_category_month.csv` (114 ô danh mục × tháng) của Pig và MapReduce giống hệt từng byte, tổng bằng Câu 1 (đối chiếu cả Spark ở mục 4.5.1). Tỷ lệ trả theo ô dao động 2,52% – 14,29% quanh mức chung 7,73%; mỗi ô chỉ 83–179 đơn nên phần lớn là dao động ngẫu nhiên.

### 4.1.4. Kết quả Spark (Câu 6)

Spark ghi vùng curated `/btl/curated/orders` (Parquet, 14.408 đơn, 45 cột, 114 phân vùng) và năm tập kết quả trong `/btl/output/cau06_spark/` ([Bảng:c06-dau-ra], mục 3.6). Vùng curated 2,35 MB, gần bằng CSV gốc dù số cột tăng từ 23 lên 45, nhờ Parquet lưu theo cột và nén. 64 sản phẩm tăng trưởng nhanh và 369 khách có nguy cơ rời bỏ được phân tích ở mục 4.2.2.
