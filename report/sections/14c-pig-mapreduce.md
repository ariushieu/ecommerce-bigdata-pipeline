### 1.4.2. Apache Pig và Hadoop MapReduce

**Hadoop MapReduce** là mô hình lập trình song song [TL:dean2004]: `map` biến mỗi bản ghi thành cặp khóa–giá trị, `reduce` gộp mọi giá trị cùng khóa; khung xử lý lo *shuffle & sort* và chạy lại tác vụ lỗi [TL:white2015], [TL:hadoop-mr-tutorial]. **Apache Pig** cung cấp ngôn ngữ luồng dữ liệu Pig Latin, dịch kịch bản thành DAG các job MapReduce [TL:olston2008], [TL:pig-docs].

*[Bảng:c04-cong-cu-pig-mr]. Vai trò và lý do chọn Pig, MapReduce*

| Công cụ | Phiên bản | Vai trò | Lý do chọn |
|---|---|---|---|
| Hadoop MapReduce | 3.2.2 | Câu 5: doanh thu, tỷ lệ trả theo danh mục × tỉnh × tháng | Kiểm soát khóa, giá trị, Combiner, Partitioner |
| Apache Pig | 0.17.0 (`mapreduce`) | Câu 4: làm sạch → staging; JOIN hai bảng danh mục; tổng hợp | Kịch bản ngắn, có sẵn `JsonLoader`, replicated join |

**Nhận xét [Bảng:c04-cong-cu-pig-mr]:** Cùng tầng thực thi nhưng khác mức trừu tượng: MapReduce tự định nghĩa từng cặp khóa–giá trị, Pig mô tả luồng dữ liệu và tự sinh job.
