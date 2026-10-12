## 5.3. Hướng phát triển

1. **Hoàn thiện lớp tốc độ:** thêm Kafka làm hàng đợi giữa Flume và bộ xử lý. Dùng Spark Structured Streaming tính doanh thu và tỷ lệ trả theo cửa sổ `event_time` có watermark, rồi phát cảnh báo khi tỷ lệ trả của một danh mục vượt ngưỡng do lớp lô tính.
2. **Kiểm thử ở quy mô thật:** sinh dữ liệu giả lập 10–100 GB (nhiều block, nhiều tác vụ map). Đo lại Pig – MapReduce – Spark để thấy rõ khả năng mở rộng, và thử gộp tệp nhỏ trong vùng curated.
3. **Tính sẵn sàng cao:** cấu hình NameNode HA với Quorum Journal Manager và HMaster dự phòng; dùng erasure coding cho dữ liệu raw cũ để giảm dung lượng nhân bản (mục 3.2.1).
4. **Bổ sung dữ liệu để giải quyết mục tiêu hoàn trả:**
   - lý do trả hàng, kích cỡ, đánh giá văn bản;
   - nhóm đối chứng cho chiến dịch và chương trình giữ chân khách.

   Sau đó thử lại mô hình phân loại, có thể bằng Spark MLlib trên toàn bộ dữ liệu.
5. **Khung kiểm soát chất lượng dữ liệu:** biến các kiểm tra ở mục 2.3 thành luật chạy tự động mỗi lần nạp dữ liệu (đếm bản ghi giữa các vùng, miền giá trị, khóa ngoại) và báo cáo kèm log.
6. **Dashboard trực tuyến:** đưa bảng tổng hợp ở vùng output lên một công cụ BI (Apache Superset hoặc IBM BigSheets thật) để người dùng nghiệp vụ tự lọc theo danh mục, tỉnh và thời gian.
