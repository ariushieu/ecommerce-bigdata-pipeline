## 4.4. Đánh giá hiệu năng

Mục này đánh giá riêng Spark (Câu 6) trên cụm 3 NodeManager, Spark 2 executor × 1 GB × 1 core; phép so có kiểm soát Pig – MapReduce – Spark ở mục 4.5.2. Thử nghiệm 1 (`src/cau06_spark/bench.py`) so cache và số phân vùng shuffle ở quy mô ×1 và ×10 (`union` 10 lần `orders.csv`, 150.000 dòng), mỗi cấu hình chạy 3 lần xen kẽ trong cùng ứng dụng, lấy trung vị; thời gian gồm đọc raw → làm sạch → join → 6 action phân tích, không gồm ghi HDFS. Thử nghiệm 2 chạy toàn bộ pipeline bằng `spark-submit` (`output/run_time.txt`).

*[Bảng:c06-hieu-nang]. Kết quả thử nghiệm hiệu năng*

| Phương pháp/cấu hình | Quy mô dữ liệu | Thời gian xử lý | Nhận xét |
|---|---|---|---|
| Spark, **cache**, 12 phân vùng shuffle | ×1: 15.000 đơn (2,3 MB) | **4,8 s** (4,2–5,8) | 23 stage, 126 task; đọc 7,06 MB |
| Spark, **không cache**, 12 phân vùng | ×1 | 7,5 s (5,1–8,2) | 29 stage, 165 task; đọc 16,18 MB |
| Spark, cache, **200** phân vùng | ×1 | 19,5 s (13,9–21,8) | 1.732 task |
| Spark, **cache**, 12 phân vùng | ×10: 150.000 đơn (23 MB) | **8,0 s** (6,9–10,2) | 153 task; đọc 49,16 MB |
| Spark, **không cache**, 12 phân vùng | ×10 | 12,5 s (11,4–17,6) | 219 task; đọc 140,31 MB |
| Spark, cache, **200** phân vùng | ×10 | 18,8 s (15,6–28,6) | 1.759 task |
| Spark: **toàn bộ pipeline Câu 6** | ×1 | 42,6 – 80,7 s (3 lần) | Lần nhanh nhất 33,6 s trong ứng dụng: đọc + làm sạch + join 7,0 s; phân tích 8,3 s; ghi curated 5,6 s; ghi kết quả 3,5 s |

**Nhận xét [Bảng:c06-hieu-nang]:**
- **Cache nhanh hơn 1,56 lần ở cả hai quy mô**: không cache, mỗi action đọc lại CSV và làm lại join nên dữ liệu đọc tăng 2,3 lần (×1) và 2,85 lần (×10).
- **200 phân vùng shuffle là sai cấu hình với dữ liệu nhỏ**: chậm hơn 4,1 lần (×1) và 2,35 lần (×10) vì mỗi `groupBy` tạo 200 task chỉ xử lý vài chục dòng; Spark 3.1 mặc định chưa bật Adaptive Query Execution nên nhóm đặt 12 [TL:spark-tuning].
- **Dữ liệu tăng 10 lần, thời gian chỉ tăng 1,67 lần**: chi phí cố định (lập lịch, khởi tạo task, broadcast) vẫn chiếm phần lớn.
- Pipeline chạy 42,6 s khi cụm rảnh, 80,7 s khi cụm bận job khác; vì cụm dùng chung, nhóm chỉ kết luận trên chênh lệch lớn hơn độ dao động.

*[Bảng:c06-io-mr-spark]. So sánh I/O khi thực hiện toàn bộ Câu 6 bằng MapReduce (ước tính) và Spark (đo được)*

| Khía cạnh | MapReduce (ước tính của nhóm) | Spark (đo được, `pipeline_metrics.json`) |
|---|---|---|
| Số job | 6–8 job nối tiếp, mỗi job một bước phân tích | 1 ứng dụng, 11 job trên cùng các executor |
| Đọc HDFS | Mỗi job đọc lại staging, khoảng 6 × 2,3 MB | 7,06 MB |
| Ghi trung gian | Mỗi job ghi HDFS 3 bản sao; map output ra đĩa cục bộ (Câu 5: 957.009 B) | Không ghi HDFS; shuffle 0,25 MB, 0 byte tràn đĩa |
| Khởi động | Khoảng 18 s mỗi job (đo ở Câu 5), trên 100 s nếu tuần tự | Một lần, khoảng 8 s (7,7–8,3 s) |
| Join danh mục | Map-side join qua Distributed Cache | `broadcast` do Catalyst chọn |

**Nhận xét [Bảng:c06-io-mr-spark]:** chi phí của MapReduce chủ yếu là khởi động 6–8 job và ghi trung gian, không phải tính toán; Spark giữ DAG cả pipeline, gộp biến đổi hẹp vào cùng stage và giữ dữ liệu dùng chung trong bộ nhớ [TL:zaharia2012]. Cột MapReduce là **ước tính** từ chi phí mỗi job đo ở Câu 5.
