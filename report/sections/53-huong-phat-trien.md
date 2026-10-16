## 5.3. Hướng phát triển

1. **Hoàn thiện lớp tốc độ:** thêm Kafka giữa Flume và bộ xử lý; dùng Spark Structured Streaming tính doanh thu, tỷ lệ trả theo cửa sổ `event_time` có watermark và cảnh báo khi vượt ngưỡng do lớp lô tính.
2. **Kiểm thử ở quy mô thật:** sinh 10–100 GB dữ liệu giả lập (nhiều block) rồi đo lại Pig – MapReduce – Spark.
3. **Tính sẵn sàng cao:** NameNode HA với Quorum Journal Manager, HMaster dự phòng; erasure coding cho dữ liệu raw cũ (mục 3.2.1).
4. **Bổ sung dữ liệu cho mục tiêu hoàn trả:** lý do trả hàng, kích cỡ, đánh giá văn bản, nhóm đối chứng; sau đó thử lại mô hình phân loại bằng Spark MLlib.
5. **Kiểm soát chất lượng tự động:** biến các kiểm tra ở mục 2.3 thành luật chạy mỗi lần nạp dữ liệu.
6. **Dashboard trực tuyến:** đưa vùng output lên công cụ BI (Apache Superset hoặc IBM BigSheets thật) để người dùng tự lọc.
