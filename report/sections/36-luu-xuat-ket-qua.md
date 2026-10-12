## 3.6. Lưu và xuất kết quả

Kết quả được lưu ở ba tầng: **HDFS** (vùng curated và output) cho phân tích lô, **tệp CSV nhỏ trong kho mã** cho báo cáo và kiểm thử tự động, **HBase** cho truy cập trực tuyến theo khóa. Dung lượng lấy từ `src/cau06_spark/output/hdfs_outputs.txt` và `src/cau07_hbase/output/*.txt`; nội dung từng tập kết quả Spark ở mục 4.1.4.

*[Bảng:c06-dau-ra]. Các đầu ra của Câu 6, Câu 7 và Câu 8*

| Đầu ra | Định dạng | Vị trí | Kích thước (1 bản sao) |
|---|---|---|---:|
| Vùng curated `orders` (14.408 đơn, 45 cột) | Parquet (Snappy), phân vùng `year/month/category` | `/btl/curated/orders/` | 2.352.399 byte |
| Danh mục × tháng | CSV | `/btl/output/cau06_spark/category_month/` | 4.293 byte |
| Tăng trưởng sản phẩm / sản phẩm tăng nhanh | Parquet / CSV | `/btl/output/cau06_spark/product_growth/`, `fast_growing_products/` | 61.976 / 6.227 byte |
| Rời bỏ toàn bộ khách / khách HIGH, MEDIUM | Parquet / CSV | `/btl/output/cau06_spark/customer_churn/`, `churn_risk_customers/` | 39.140 / 36.409 byte |
| Tóm tắt, nhật ký (`pipeline_log.txt`, `pipeline_metrics.json`, …) | CSV, TXT, JSON | `src/cau06_spark/output/` | dưới 40 KB mỗi tệp |
| Bảng `btl:customer_orders` | HFile Snappy + FAST_DIFF | `/hbase/data/btl/customer_orders` | 3.446.349 byte |
| Bản sao lưu HBase | Snapshot + HFile | `/btl/backup/hbase/` | 3.445.584 byte |
| Dashboard BigSheets (Câu 8) | CSV | `src/cau08_bigsheets/output/` | – |

**Nhận xét [Bảng:c06-dau-ra]:**
- **Parquet cho dữ liệu chi tiết, CSV cho kết quả nhỏ.** Parquet lưu theo cột, có schema và nén nên công cụ sau (Spark, R với `arrow`) chỉ đọc đúng cột và phân vùng; CSV mở được bằng Excel, BigSheets và `diff` được giữa ba công cụ. Kết quả tổng hợp dùng `coalesce(1)` cho một tệp mỗi thư mục, chấp nhận được vì chỉ vài nghìn dòng.
- **Phân vùng theo tháng và danh mục** khớp kiểu truy vấn thường gặp, đổi lại là 114 tệp nhỏ (khoảng 20 KB); nếu ở quy mô thật phân vùng vẫn nhỏ thì nên bỏ cấp `category` hoặc gộp tệp định kỳ.
- Mỗi lần chạy ghi đè (`mode("overwrite")`) nên kết quả tái lập được, `test.sh` so với tệp đã commit. HBase và curated chứa cùng 14.408 đơn nhưng HBase sắp theo khách – thời gian đảo cho tra cứu từng khách.
