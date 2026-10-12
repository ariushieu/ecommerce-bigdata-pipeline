## 4.4. Đánh giá hiệu năng

Mục này đánh giá riêng Spark (Câu 6) trên cụm 3 NodeManager (mỗi máy 2.560 MB, 2 vcore), Spark 2 executor × 1 GB × 1 core; phép so có kiểm soát Pig – MapReduce – Spark trên cùng một bài toán nằm ở mục 4.5.2. Hai thử nghiệm:
1. **Cache và số phân vùng shuffle** ở quy mô ×1 và ×10, trong cùng một ứng dụng Spark, mỗi cấu hình chạy 3 lần xen kẽ, lấy trung vị (`src/cau06_spark/bench.py`, `output/bench_spark.csv`). Thời gian đo gồm đọc raw → làm sạch → join → 6 action phân tích, không gồm ghi HDFS. Quy mô ×10 tạo bằng `union` 10 lần đọc `orders.csv` (150.000 dòng).
2. **Toàn bộ pipeline Câu 6** chạy bằng `spark-submit` (`output/run_time.txt`, `pipeline_metrics.json`).

Lệnh tái lập: `bash cau06_spark/run.sh --bench` trong `ssh may1` (khoảng 15 phút).

*[Bảng:c06-hieu-nang]. Kết quả thử nghiệm hiệu năng*

| Phương pháp/cấu hình | Quy mô dữ liệu | Thời gian xử lý | Nhận xét |
|---|---|---|---|
| Spark, **cache**, 12 phân vùng shuffle | ×1: 15.000 đơn (2,3 MB) | **4,8 s** (4,2–5,8) | 11 job, 23 stage, 126 task; đọc 7,06 MB; shuffle 0,25 MB |
| Spark, **không cache**, 12 phân vùng | ×1 | 7,5 s (5,1–8,2) | 29 stage, 165 task; đọc 16,18 MB; shuffle 0,82 MB |
| Spark, cache, **200** phân vùng | ×1 | 19,5 s (13,9–21,8) | 1.732 task; đọc 7,06 MB; shuffle 0,37 MB |
| Spark, **cache**, 12 phân vùng | ×10: 150.000 đơn (23 MB) | **8,0 s** (6,9–10,2) | 153 task; đọc 49,16 MB; shuffle 0,33 MB |
| Spark, **không cache**, 12 phân vùng | ×10 | 12,5 s (11,4–17,6) | 219 task; đọc 140,31 MB; shuffle 2,57 MB |
| Spark, cache, **200** phân vùng | ×10 | 18,8 s (15,6–28,6) | 1.759 task; đọc 49,16 MB; shuffle 0,57 MB |
| Spark: **toàn bộ pipeline Câu 6** (đọc, làm sạch, join, 4 phân tích, ghi curated + 5 kết quả) | ×1 | 42,6 – 80,7 s (3 lần) | Lần nhanh nhất: trong ứng dụng 33,6 s, gồm đọc + làm sạch + join 7,0 s; phân tích 8,3 s; ghi curated 5,6 s; ghi kết quả 3,5 s |

**Nhận xét [Bảng:c06-hieu-nang]:**
- **Cache nhanh hơn 1,56 lần ở cả hai quy mô** (7,5 so với 4,8 s; 12,5 so với 8,0 s). Không cache, mỗi action đọc lại CSV và làm lại join, nên dữ liệu đọc vào tăng 2,3 lần (×1) và 2,85 lần (×10), thêm 6 stage.
- **200 phân vùng shuffle là sai cấu hình với dữ liệu nhỏ**: chậm hơn 4,1 lần (×1) và 2,35 lần (×10) vì mỗi `groupBy` tạo 200 task chỉ xử lý vài chục dòng. Spark 3.1 mặc định chưa bật Adaptive Query Execution, nên nhóm đặt `spark.sql.shuffle.partitions = 12` [TL:spark-tuning].
- **Tăng dữ liệu 10 lần, thời gian chỉ tăng 1,67 lần** (4,8 → 8,0 s): chi phí cố định (lập lịch, khởi tạo task, broadcast) vẫn chiếm phần lớn.
- Toàn bộ pipeline chạy 42,6 s khi cụm rảnh, 80,7 s khi cụm bận job của thành viên khác. Vì cụm dùng chung nên khoảng min–max rộng; nhóm dùng trung vị và chỉ kết luận trên các chênh lệch lớn hơn độ dao động, còn số liệu I/O giống hệt nhau giữa các lần lặp.

*[Bảng:c06-io-mr-spark]. So sánh I/O khi thực hiện toàn bộ Câu 6 bằng MapReduce (ước tính) và Spark (đo được)*

| Khía cạnh | MapReduce (ước tính của nhóm) | Spark (đo được, `pipeline_metrics.json`) |
|---|---|---|
| Số job | 6–8 job nối tiếp: làm sạch + map-side join → staging; danh mục × tháng; tăng trưởng sản phẩm; tổng hợp theo khách; xếp hạng RFM toàn cục; reduce-side join sự kiện | 1 ứng dụng, 11 job do action sinh ra, trên cùng các executor |
| Đọc HDFS | Mỗi job đọc lại staging, tổng khoảng 6 × 2,3 MB | 7,06 MB cho toàn bộ phân tích |
| Ghi trung gian | Kết quả mỗi job ghi HDFS 3 bản sao; map output ghi đĩa cục bộ (job danh mục × tháng của Câu 5 ghi 957.009 B) | Không ghi HDFS giữa các bước; shuffle 0,25 MB, 0 byte tràn đĩa |
| Khởi động | Mỗi job khoảng 18 s (đo ở Câu 5), trên 100 s nếu chạy tuần tự | Một lần, khoảng 8 s (7,7–8,3 s đo khi chạy riêng `category_month_only.py`) |
| Join danh mục | Map-side join qua Distributed Cache (tự cài) | `broadcast` do Catalyst chọn |

**Nhận xét [Bảng:c06-io-mr-spark]:**
- Với Câu 6, chi phí của MapReduce chủ yếu là khởi động 6–8 job và ghi trung gian, không phải tính toán; Spark giữ DAG cả pipeline, gộp phép biến đổi hẹp vào cùng stage và giữ dữ liệu dùng chung trong bộ nhớ [TL:zaharia2012].
- Cột MapReduce là **ước tính** từ số job cần thiết và chi phí mỗi job đo ở Câu 5; tính đúng của kết quả được xác thực ở mục 4.5.1.
