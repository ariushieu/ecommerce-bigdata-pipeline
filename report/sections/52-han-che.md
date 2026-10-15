## 5.2. Hạn chế

- **Dữ liệu:** dữ liệu giả lập phân bố gần đồng đều theo mọi chiều, nên nhiều phân tích chỉ cho tín hiệu yếu (tỷ lệ trả gần như không đổi, nguy cơ rời bỏ chưa vượt mức ngẫu nhiên, AUC 0,493). Không có lý do trả hàng, nhóm đối chứng hay chi phí giao hàng nên chưa đo được tác động nhân quả của khuyến nghị.
- **Quy mô:** bộ dữ liệu khoảng 7 MB; tăng ×10 vẫn nằm trong một block HDFS, nên phép so Pig – MapReduce – Spark chủ yếu đo chi phí khởi động job. I/O của pipeline Câu 6 trên MapReduce chỉ là ước tính.
- **Môi trường:** cụm 4 node chạy trong Docker trên một máy, nên mạng và đĩa giữa các node là của cùng một máy; NameNode và HMaster là điểm hỏng duy nhất (không có HA). Một số phép đo chạy khi cụm đang bận và đã được ghi chú; [Bảng:c10-hieu-nang] đo khi cụm rảnh.
- **Công nghệ:** BigSheets chỉ được mô phỏng, không dùng Kafka; lớp tốc độ dừng ở thu thập vào HBase và tra cứu, chưa cài tính toán cửa sổ có watermark (mục 1.3.7).
