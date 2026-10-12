## 5.2. Hạn chế

- **Dữ liệu**
  - Dữ liệu giả lập, phân bố gần đồng đều theo mọi chiều, nên nhiều phân tích nghiệp vụ chỉ cho tín hiệu yếu: tỷ lệ trả gần như không đổi, nguy cơ rời bỏ chưa vượt mức ngẫu nhiên, mô hình phân loại có AUC 0,493.
  - Dữ liệu không có lý do trả hàng, nhóm đối chứng của chiến dịch hay chi phí giao hàng, nên chưa đo được tác động nhân quả của các khuyến nghị.
- **Quy mô**
  - Bộ dữ liệu chỉ khoảng 7 MB. Tăng ×10 vẫn nằm trong một block HDFS, nên phép so hiệu năng Pig – MapReduce – Spark chủ yếu đo chi phí khởi động job, chưa thể hiện khả năng mở rộng.
  - So sánh I/O của toàn bộ pipeline Câu 6 trên MapReduce là ước tính, không phải phép đo.
- **Môi trường**
  - Cụm 4 node chạy trong Docker trên một máy tính, nên "mạng" và "đĩa" giữa các node thực chất là của cùng một máy. Kết quả hiệu năng không đại diện cho cụm thật.
  - NameNode và HMaster là điểm hỏng duy nhất (không cấu hình HA).
  - Một số phép đo được thực hiện khi cụm đang chạy job của câu khác. Các phép đo đó đã được ghi chú; bảng đối chiếu chính ([Bảng:c10-hieu-nang]) đo khi cụm rảnh.
- **Công nghệ**
  - BigSheets chỉ được mô phỏng (không có IBM BigInsights). Kafka không được dùng.
  - Lớp tốc độ dừng ở mức thu thập vào HBase và tra cứu: chưa cài đặt tính toán cửa sổ theo `event_time` có watermark như thiết kế ở mục 1.3.7.
