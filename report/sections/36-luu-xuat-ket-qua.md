## 3.6. Lưu và xuất kết quả

Kết quả được lưu ở ba tầng: **HDFS** cho phân tích lô, **CSV nhỏ trong kho mã** cho báo cáo và kiểm thử, **HBase** cho tra cứu trực tuyến theo khóa. Nội dung từng tập kết quả ở mục 4.1.4.

*[Bảng:c06-dau-ra]. Các đầu ra của Câu 6 và Câu 7 (1 bản sao, `hdfs_outputs.txt`)*

| Đầu ra | Định dạng | Vị trí | Byte |
|---|---|---|---:|
| Curated `orders` (14.408 đơn, 45 cột) | Parquet (Snappy) | `/btl/curated/orders/` | 2.352.399 |
| Danh mục × tháng | CSV | `/btl/output/cau06_spark/category_month/` | 4.293 |
| Tăng trưởng sản phẩm / tăng nhanh | Parquet / CSV | `…/product_growth/`, `fast_growing_products/` | 61.976 / 6.227 |
| Rời bỏ toàn bộ khách / HIGH, MEDIUM | Parquet / CSV | `…/customer_churn/`, `churn_risk_customers/` | 39.140 / 36.409 |
| Bảng `btl:customer_orders` | HFile Snappy + FAST_DIFF | `/hbase/data/btl/customer_orders` | 3.446.349 |
| Bản sao lưu HBase | Snapshot + HFile | `/btl/backup/hbase/` | 3.445.584 |

**Nhận xét [Bảng:c06-dau-ra]:**
- **Parquet cho dữ liệu chi tiết** (theo cột, nén, nên Spark và R chỉ đọc đúng cột và phân vùng); **CSV cho kết quả nhỏ** (mở bằng Excel, BigSheets, `diff` được giữa ba công cụ).
- Phân vùng theo tháng và danh mục đổi lại 114 tệp nhỏ (khoảng 20 KB); ở quy mô thật nên bỏ cấp `category` hoặc gộp tệp định kỳ. Mỗi lần chạy ghi đè nên kết quả tái lập được và `test.sh` so được với tệp đã commit.
