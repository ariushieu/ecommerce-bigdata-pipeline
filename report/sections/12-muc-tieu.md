## 1.2. Mục tiêu của đề tài

**Mục tiêu tổng quát:** nền tảng phân tích dữ liệu lớn tích hợp đơn hàng theo lô và sự kiện thời gian thực, phục vụ ba mục tiêu: **tối ưu doanh thu, giảm tỷ lệ hoàn trả và rút ngắn thời gian giao hàng**.

*[Bảng:muc-tieu-cu-the]. Mục tiêu cụ thể và tiêu chí đánh giá*

| # | Mục tiêu | Tiêu chí đo được | Câu |
|---|---|---|---|
| 1 | Phân tích đặc trưng Big Data, chất lượng dữ liệu | Đủ 5V có số liệu; vấn đề chất lượng được đếm | 1 |
| 2 | Thu thập lô và luồng không mất dữ liệu | 2 kịch bản Flume; 5.000/5.000 sự kiện tới đích | 2 |
| 3 | Lưu trữ phân tán theo vùng | 4 vùng; nhân bản 3 lần; chịu hỏng 1 node | 3 |
| 4 | Làm sạch thống nhất | 15.000 → 14.408 đơn sạch ở mọi công cụ | 4, 5, 6 |
| 5 | Doanh thu, tỷ lệ trả theo danh mục, tỉnh, tháng | Pig, MapReduce, Spark khớp từng ô | 4, 5, 6 |
| 6 | Sản phẩm tăng trưởng nhanh, khách có nguy cơ rời bỏ | Danh sách xếp hạng có tiêu chí | 6 |
| 7 | Truy cập ngẫu nhiên lịch sử đơn | N đơn mới nhất bằng một lần quét tiền tố | 7 |
| 8 | Dashboard theo danh mục và tỉnh | Người không lập trình tái tạo được | 8 |
| 9 | Hồi quy doanh thu, phân loại trả hàng | R², AUC so với mô hình cơ sở | 9 |
| 10 | Khuyến nghị có căn cứ | Ít nhất 5 khuyến nghị gắn số liệu cụ thể | 10 |

**Nhận xét [Bảng:muc-tieu-cu-the]:** mỗi mục tiêu ứng với một câu của đề, có tiêu chí kiểm chứng được (đánh giá ở mục 4.5.3). Mốc ban đầu ([Bảng:kpi-danh-muc]): doanh thu ròng 78.218.341,22, tỷ lệ trả 7,73%, giao trung bình 3,04 ngày.

**Phạm vi:** dữ liệu giả lập của giảng viên (15.000 đơn 01/2025 – 07/2026, 1.200 khách, 400 sản phẩm, 5.000 sự kiện); cụm Hadoop 4 node (1 master, 3 worker); BigSheets mô phỏng; không dùng Kafka.
