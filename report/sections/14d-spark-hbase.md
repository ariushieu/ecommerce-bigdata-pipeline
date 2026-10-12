### 1.4.3. Apache Spark và Apache HBase

**Apache Spark** là engine xử lý phân tán trong bộ nhớ. Dữ liệu là *Resilient Distributed Dataset* (RDD): tập chỉ đọc, chia phân vùng, dựng lại được từ dòng dõi (*lineage*) khi mất node [TL:zaharia2012]. Spark SQL bổ sung DataFrame và bộ tối ưu Catalyst, tự chọn kế hoạch như broadcast join hay đẩy bộ lọc xuống nguồn [TL:armbrust2015]. Transformation chỉ ghi vào DAG; action mới khởi chạy job [TL:spark-docs].

**Apache HBase** là cơ sở dữ liệu cột rộng trên HDFS theo mô hình Bigtable [TL:chang2006]. Mỗi ô là `(rowkey, family:qualifier, timestamp) → giá trị`, sắp theo rowkey và chia thành *region* do RegionServer phục vụ, nên đọc/ghi ngẫu nhiên theo khóa trong vài mili giây, việc HDFS không làm được [TL:george2011].

*[Bảng:c06-cong-nghe-spark-hbase]. Vai trò và lý do chọn Spark, HBase trong đề tài*

| Công cụ | Phiên bản | Vai trò | Lý do chọn |
|---|---|---|---|
| Apache Spark (PySpark) | 3.1.2 trên YARN, 2 executor × 1 GB | Câu 6: làm sạch, join, ghi curated, tăng trưởng sản phẩm, rời bỏ khách | Một chương trình thay chuỗi job MapReduce; `cache`; Spark SQL, hàm cửa sổ |
| Apache HBase | 2.5.16, 1 HMaster, 3 RegionServer | Câu 7: bảng `btl:customer_orders` tra cứu đơn theo khách | Truy cập theo rowkey; nhiều phiên bản; TTL, nén, snapshot, ACL |

**Nhận xét [Bảng:c06-cong-nghe-spark-hbase]:**
- Theo kiến trúc Lambda (mục 1.3.7), Spark là **lớp lô**, HBase là **lớp phục vụ**; cả hai dùng chung YARN/HDFS với Pig, MapReduce.
- Với 2,3 MB đơn hàng, lợi thế của Spark là ít job hơn và không ghi HDFS giữa các bước (mục 4.4).
