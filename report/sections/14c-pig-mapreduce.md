### 1.4.2. Apache Pig và Hadoop MapReduce

**Hadoop MapReduce** là mô hình lập trình song song do Google đề xuất [TL:dean2004]: hàm `map` biến mỗi bản ghi thành các cặp khóa–giá trị trung gian, hàm `reduce` gộp mọi giá trị cùng khóa. Khung xử lý lo chia split, sắp xếp và chuyển dữ liệu trung gian (*shuffle & sort*), chạy lại tác vụ lỗi; trong Hadoop 3, job chạy trên YARN, đọc/ghi HDFS [TL:white2015], [TL:hadoop-mr-tutorial].

**Apache Pig** cung cấp ngôn ngữ luồng dữ liệu Pig Latin; mỗi câu lệnh (LOAD, FILTER, JOIN, GROUP, FOREACH, ORDER, STORE…) là một phép biến đổi trên quan hệ [TL:olston2008]. Pig dịch kịch bản thành DAG các job MapReduce và tự tối ưu, ví dụ gộp các nhánh đọc cùng đầu vào thành một job (*multi-query execution*) [TL:pig-docs].

*[Bảng:c04-cong-cu-pig-mr]. Vai trò và lý do chọn Pig, MapReduce*

| Công cụ | Phiên bản | Vai trò trong đề tài | Lý do chọn |
|---|---|---|---|
| Hadoop MapReduce | 3.2.2 (Java 8, chạy trên YARN) | Câu 5: doanh thu, tỷ lệ trả theo danh mục × tỉnh × tháng | Kiểm soát trực tiếp khóa, giá trị, Combiner, Partitioner; mốc so sánh cho Pig, Spark |
| Apache Pig | 0.17.0 (chế độ `mapreduce`) | Câu 4: làm sạch → `/btl/staging/orders`; JOIN với `customers`, `products`; tổng hợp theo danh mục × phân khúc | Kịch bản ngắn, không cần biên dịch; có sẵn `JsonLoader`, replicated join, hàm tổng hợp |

**Nhận xét [Bảng:c04-cong-cu-pig-mr]:** Hai công cụ dùng chung tầng thực thi (MapReduce trên YARN) nhưng khác mức trừu tượng: với MapReduce, người viết tự định nghĩa từng cặp khóa–giá trị; với Pig, người viết mô tả luồng dữ liệu, Pig tự sinh job. Với tệp 2,3 MB, cả hai tốn phần lớn thời gian cho khởi động job (mục 4.1).
