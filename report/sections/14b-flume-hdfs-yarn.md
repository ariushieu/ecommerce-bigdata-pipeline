### 1.4.1. Apache Flume, HDFS và YARN

Ba thành phần nền của hệ thống: **Flume** đưa dữ liệu vào cụm, **HDFS** lưu dữ liệu bền vững, **YARN** chia tài nguyên tính toán cho các công cụ xử lý.

*[Bảng:c02-cong-nghe-nen]. Vai trò và lý do chọn Flume, HDFS, YARN*

| Công cụ | Phiên bản | Vai trò trong đề tài | Lý do chọn |
|---|---|---|---|
| Apache Flume | 1.11.0 | Thu thập (Câu 2): nạp CSV theo lô bằng *spooling directory*; nhận `order_event` qua HTTP; ghi vào HDFS và HBase | Cấu hình khai báo Source–Channel–Sink, không phải viết mã; có giao dịch và FileChannel bền vững; có sẵn sink HDFS và HBase 2 [TL:flume-guide] |
| HDFS | Hadoop 3.2.2 | Lưu bốn vùng raw/staging/curated/output (Câu 3); nơi HBase lưu HFile và WAL | Block 128 MiB, nhân bản 3 lần nên chịu được hỏng node; tối ưu đọc tuần tự khối lớn [TL:shvachko2010], [TL:white2015] |
| YARN | Hadoop 3.2.2 | Cấp CPU, bộ nhớ cho Pig, MapReduce, Spark trên 3 NodeManager | Một bộ quản lý tài nguyên dùng chung cho nhiều framework; chạy lại container khi node hỏng [TL:vavilapalli2013] |

**Nhận xét [Bảng:c02-cong-nghe-nen]:**
- **Flume** xử lý được cả hai chế độ lô và luồng, chỉ khác source. Kafka bền và mở rộng tốt hơn nhưng cần thêm cụm broker; với khoảng 23 sự kiện/giây (mục 1.3.2), một agent Flume là đủ, và có thể thay HTTP source bằng Kafka khi tải tăng.
- **HDFS** hợp với mô hình *ghi một lần, đọc nhiều lần*; truy cập ngẫu nhiên theo khóa do HBase đảm nhận (mục 1.4.3).
- **YARN** cho Pig, MapReduce và Spark chạy chung một cụm, nhờ đó so sánh được ba công cụ trên cùng phần cứng (mục 4.4).
