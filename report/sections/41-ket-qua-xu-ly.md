## 4.1. Kết quả xử lý

Mục này trình bày kết quả tiêu biểu của Pig (Câu 4, `src/cau04_pig/output/`), MapReduce (Câu 5, `src/cau05_mapreduce/output/`) và Spark (Câu 6) trên **14.408 đơn sạch** của bản chụp `ingest_date=2026-08-01`. Các bảng là kết quả thật từ HDFS.

### 4.1.1. Kết quả Pig (Câu 4)

*[Bảng:c04-kq-danh-muc]. Tổng hợp theo danh mục sau JOIN với `customers`, `products` (`category_summary.tsv`)*

| Danh mục | Đơn | Khách hàng khác nhau | Doanh thu ròng | Đơn trả | Tỷ lệ trả (%) | Ngày giao TB |
|---|---:|---:|---:|---:|---:|---:|
| Books | 2.953 | 1.108 | 15.741.983,83 | 224 | 7,59 | 2,99 |
| Home | 2.616 | 1.072 | 14.257.300,58 | 196 | 7,49 | 3,05 |
| Electronics | 2.505 | 1.042 | 14.086.726,93 | 189 | 7,54 | 3,06 |
| Sports | 2.280 | 1.002 | 12.994.254,03 | 180 | 7,89 | 2,97 |
| Beauty | 2.219 | 1.033 | 11.426.625,74 | 169 | 7,62 | 3,11 |
| Fashion | 1.835 | 936 | 9.711.450,11 | 156 | 8,50 | 3,09 |

**Nhận xét [Bảng:c04-kq-danh-muc]:**
- Mọi chỉ số của 6 danh mục **trùng khớp** với profiling ở Câu 1, nên Pig làm sạch và JOIN không làm mất hay nhân bản đơn nào.
- Books dẫn đầu về số đơn và doanh thu; Fashion thấp nhất nhưng tỷ lệ trả cao nhất (8,50%). Mỗi danh mục có 936–1.108 trong tổng 1.200 khách, tức khách mua trải đều.

*[Bảng:c04-kq-phan-khuc]. Doanh thu ròng theo danh mục × phân khúc khách hàng (GROUP BY `category, customer_segment`, `segment_stats.tsv`)*

| Danh mục | Loyal | New | Regular | VIP |
|---|---:|---:|---:|---:|
| Beauty | 2.965.366,55 | 3.008.979,39 | 2.611.058,27 | 2.841.221,53 |
| Books | **4.188.020,25** | 4.074.021,12 | 3.950.340,52 | 3.529.601,94 |
| Electronics | 3.489.757,81 | 3.455.277,15 | 3.695.033,04 | 3.446.658,93 |
| Fashion | *2.111.320,42* | 2.637.522,29 | 2.462.405,06 | 2.500.202,34 |
| Home | 3.600.387,79 | 3.785.740,80 | 3.417.710,28 | 3.453.461,71 |
| Sports | 3.118.603,92 | 3.544.279,58 | 3.118.900,05 | 3.212.470,48 |

**Nhận xét [Bảng:c04-kq-phan-khuc]:**
- 24 nhóm có 412–772 đơn, cao nhất Books × Loyal (772 đơn), thấp nhất Fashion × Loyal (412 đơn). Giá trị đơn trung bình chỉ dao động 4.936,51–5.829,41, nên chênh lệch doanh thu chủ yếu do **số đơn**.
- Tỷ lệ trả theo nhóm trùng từng giá trị với ma trận R ở [Bảng:c09-ma-tran-tra] (ví dụ Fashion × Loyal 9,47%).

Kết quả ORDER … DESC + LIMIT 10 (`top10_products.tsv`): dẫn đầu là P0310 (Books, 502.072,27); Home chiếm 6/10 sản phẩm dù tổng doanh thu đứng sau Books; điểm sản phẩm (2,6–4,9) không đi cùng thứ hạng doanh thu.

*[Bảng:c04-thoi-gian]. Thời gian chạy kịch bản Pig trên cụm (`runtime.txt`, `pig_job_timeline.tsv`)*

| Chỉ số | Giá trị |
|---|---:|
| Số job MapReduce Pig sinh ra | 17 |
| Thời gian từ lúc gọi `pig` đến khi xong | 339,1 s |
| Tổng thời gian **chạy** của 17 job | 129,0 s (mỗi job 4,2–9,1 s) |
| Tổng thời gian **chờ** YARN cấp tài nguyên | 479,9 s |

**Nhận xét [Bảng:c04-thoi-gian]:** Thời gian chạy gần như toàn là chi phí khởi động job; phần lớn còn lại là **chờ cấp container**, vì các nhánh độc lập của DAG được nộp cùng lúc và trùng lúc job Spark của Câu 6. Với dữ liệu nhỏ, cần **giảm số job**: bản đầu 26 job mất 583,9 s (mục 4.4).

### 4.1.2. Kết quả MapReduce (Câu 5)

Kết quả chính `category_province_month.tsv` có **2.049 dòng** trên 6 × 18 × 19 = 2.052 bộ (danh mục, tỉnh, tháng) có thể có; [Bảng:c05-kq-tinh] gộp theo tỉnh.

*[Bảng:c05-kq-tinh]. Doanh thu và tỷ lệ trả theo tỉnh giao hàng, gộp từ đầu ra MapReduce (`province_summary.tsv`)*

| Tỉnh giao | Đơn | Doanh thu ròng | Đơn trả | Tỷ lệ trả (%) |
|---|---:|---:|---:|---:|
| Khanh Hoa | 841 | 4.701.770,56 | 55 | 6,54 |
| Nam Dinh | 837 | 4.669.197,53 | 76 | 9,08 |
| TP Ho Chi Minh | 840 | 4.611.342,95 | 59 | 7,02 |
| Quang Nam | 823 | 4.531.936,01 | 75 | 9,11 |
| Da Nang | 816 | 4.493.772,23 | 60 | 7,35 |
| Thua Thien Hue | 819 | 4.390.161,50 | 55 | 6,72 |
| Thai Nguyen | 808 | 4.387.558,73 | 59 | 7,30 |
| Binh Duong | 800 | 4.386.709,54 | 61 | 7,62 |
| Ha Noi | 786 | 4.362.931,19 | 67 | 8,52 |
| Hai Duong | 791 | 4.289.781,99 | 67 | 8,47 |
| Quang Ninh | 784 | 4.265.168,47 | 57 | 7,27 |
| Hai Phong | 827 | 4.256.831,71 | 64 | 7,74 |
| Lam Dong | 772 | 4.243.753,37 | 60 | 7,77 |
| Nghe An | 801 | 4.229.799,14 | 47 | 5,87 |
| Bac Ninh | 769 | 4.214.587,48 | 59 | 7,67 |
| Thanh Hoa | 797 | 4.193.213,55 | 64 | 8,03 |
| Dong Nai | 760 | 4.120.715,48 | 68 | 8,95 |
| Can Tho | 737 | 3.869.109,79 | 61 | 8,28 |

**Nhận xét [Bảng:c05-kq-tinh]:**
- Doanh thu phân bố đều giữa 18 tỉnh (chênh khoảng 22% giữa Can Tho và Khanh Hoa). Tỷ lệ trả dao động 5,87–9,11%, nhưng kiểm định χ² ở [Bảng:c09-kiem-dinh] cho p = 0,553 nên **chưa đủ căn cứ** coi là khác biệt thật.
- Ở mức ô (danh mục × tỉnh × tháng), mỗi ô chỉ có 1–18 đơn và 1.190/2.049 ô (58,1%) không có đơn trả (`cell_stats.txt`), nên tỷ lệ trả từng ô rất nhiễu; khi ra quyết định nên dùng mức gộp.

*[Bảng:c05-counter]. Counter của job chính có và không có Combiner (`counters_*.txt`, `bench.tsv`)*

| Counter | Có Combiner | Không Combiner |
|---|---:|---:|
| Map input / output records | 15.001 / 14.408 | 15.001 / 14.408 |
| Combine input / output records | 14.408 / 2.049 | 0 / 0 |
| Reduce input records (= số bản ghi qua shuffle) | 2.049 | 14.408 |
| Reduce shuffle bytes | 105.658 | 742.292 |
| Spilled records | 4.098 | 28.816 |
| Thời gian job, trung bình 3 lần (`bench.sh`) | 14,6 s | 16,2 s |

**Nhận xét [Bảng:c05-counter]:**
- Counter tự định nghĩa của Mapper khớp với khảo sát ở Câu 1 (bỏ 1 tiêu đề và 592 bản ghi theo nhãn, không có dòng `MALFORMED`).
- Combiner giảm số bản ghi qua shuffle **7 lần** (14.408 → 2.049), số byte shuffle **85,8%**; hai đầu ra giống hệt (`diff`). Thời gian chỉ giảm khoảng 1,5 s (10%) vì chi phí khởi động chiếm phần lớn; lợi ích sẽ rõ hơn khi dữ liệu lớn.

### 4.1.3. Đối chiếu Pig – MapReduce

Tệp `compare_category_month.csv` (114 dòng = 6 danh mục × 19 tháng, quy ước §3) của Pig và MapReduce giống hệt từng byte (`diff`), nhờ cùng cộng tiền bằng xu và làm tròn HALF_UP bằng phép chia nguyên; tổng 14.408 đơn, 78.218.341,22 doanh thu, 1.114 đơn trả bằng Câu 1. Tỷ lệ trả theo ô dao động 2,52% (Electronics 2025-07) – 14,29% (Books 2025-03) quanh mức chung 7,73%; mỗi ô có 83–179 đơn nên biên độ này phần lớn là dao động ngẫu nhiên. Đối chiếu cả ba công cụ (thêm Spark) ở mục 4.5.1.

### 4.1.4. Kết quả Spark (Câu 6)

Pipeline Spark ghi vùng curated `/btl/curated/orders` (Parquet, 14.408 đơn, 45 cột, 114 phân vùng) và năm tập kết quả trong `/btl/output/cau06_spark/`; danh sách, định dạng và kích thước ở mục 3.6 ([Bảng:c06-dau-ra]). Vùng curated 2,35 MB, gần bằng tệp CSV gốc dù số cột tăng từ 23 lên 45, nhờ Parquet lưu theo cột và nén. Bảng danh mục × tháng của Spark trùng từng byte với Pig và MapReduce (mục 4.5); 64 sản phẩm tăng trưởng nhanh và 369 khách có nguy cơ rời bỏ được phân tích ở mục 4.2.2.
