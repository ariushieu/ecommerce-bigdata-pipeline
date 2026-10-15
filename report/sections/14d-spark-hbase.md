### 1.4.3. Apache Spark và Apache HBase

**Apache Spark** xử lý phân tán trong bộ nhớ trên RDD: tập chỉ đọc, chia phân vùng, dựng lại từ dòng dõi (*lineage*) khi mất node [TL:zaharia2012]. Spark SQL thêm DataFrame và bộ tối ưu Catalyst [TL:armbrust2015]; transformation chỉ ghi vào DAG, action mới chạy job [TL:spark-docs].

**Apache HBase** là cơ sở dữ liệu cột rộng trên HDFS theo mô hình Bigtable [TL:chang2006]: ô `(rowkey, family:qualifier, timestamp) → giá trị` sắp theo rowkey, chia thành *region*, nên đọc/ghi theo khóa chỉ vài mili giây [TL:george2011].

*[Bảng:c06-cong-nghe-spark-hbase]. Vai trò và lý do chọn Spark, HBase*

| Công cụ | Vai trò | Lý do chọn |
|---|---|---|
| Spark 3.1.2 (YARN, 2 executor × 1 GB) | Câu 6: làm sạch, join, phân tích | Thay chuỗi job MapReduce; `cache`; Spark SQL |
| HBase 2.5.16 (3 RegionServer) | Câu 7: tra cứu đơn theo khách | Truy cập theo rowkey; phiên bản; TTL, nén, snapshot, ACL |

**Nhận xét [Bảng:c06-cong-nghe-spark-hbase]:** theo kiến trúc Lambda (mục 1.3.7), Spark là lớp lô, HBase là lớp phục vụ.
