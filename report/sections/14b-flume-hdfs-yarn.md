### 1.4.1. Apache Flume, HDFS và YARN

*[Bảng:c02-cong-nghe-nen]. Vai trò và lý do chọn Flume, HDFS, YARN*

| Công cụ | Vai trò trong đề tài | Lý do chọn |
|---|---|---|
| Flume | Câu 2: nạp CSV bằng *spooling directory*, nhận `order_event` qua HTTP, ghi vào HDFS và HBase | Cấu hình Source–Channel–Sink, có giao dịch, FileChannel bền vững [TL:flume-guide] |
| HDFS | Câu 3: bốn vùng raw/staging/curated/output; HFile, WAL của HBase | Block 128 MiB, nhân bản 3 lần, tối ưu đọc tuần tự [TL:shvachko2010], [TL:white2015] |
| YARN | Cấp CPU, bộ nhớ cho Pig, MapReduce, Spark | Một bộ quản lý tài nguyên cho nhiều framework [TL:vavilapalli2013] |

**Nhận xét [Bảng:c02-cong-nghe-nen]:** Kafka bền hơn nhưng cần thêm cụm broker; với khoảng 23 sự kiện/giây (mục 1.3.2), một agent Flume là đủ. YARN cho ba công cụ xử lý chạy chung cụm nên so sánh được trên cùng phần cứng (mục 4.4).
