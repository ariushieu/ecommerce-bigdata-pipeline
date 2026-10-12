## 1.2. Mục tiêu của đề tài

**Mục tiêu tổng quát:** xây dựng nền tảng phân tích dữ liệu lớn tích hợp dữ liệu đơn hàng theo lô và sự kiện mua sắm thời gian thực, phục vụ ba mục tiêu nghiệp vụ của đề tài: **tối ưu doanh thu, giảm tỷ lệ hoàn trả và rút ngắn thời gian giao hàng**.

**Mục tiêu cụ thể và tiêu chí đo:**

*[Bảng:muc-tieu-cu-the]. Mục tiêu cụ thể và tiêu chí đánh giá*

| # | Mục tiêu | Tiêu chí đo được | Câu |
|---|---|---|---|
| 1 | Phân tích đặc trưng Big Data và chất lượng dữ liệu | Đủ 5V có số liệu; mọi vấn đề chất lượng có số lượng cụ thể và yêu cầu xử lý | 1 |
| 2 | Thu thập dữ liệu lô và luồng không mất dữ liệu | 2 kịch bản Flume chạy được; 5.000/5.000 sự kiện tới đích | 2 |
| 3 | Tổ chức lưu trữ phân tán theo vùng | 4 vùng raw/staging/curated/output; mọi tệp nhân bản 3 lần; đọc được dữ liệu khi hỏng 1 node | 3 |
| 4 | Làm sạch thống nhất | 15.000 → 14.408 đơn sạch, mọi công cụ cho cùng con số | 4, 5, 6 |
| 5 | Tính doanh thu và tỷ lệ trả theo danh mục, tỉnh, tháng | Kết quả Pig, MapReduce, Spark khớp nhau từng ô | 4, 5, 6 |
| 6 | Phát hiện sản phẩm tăng trưởng nhanh, khách có nguy cơ rời bỏ | Danh sách xếp hạng có tiêu chí rõ ràng | 6 |
| 7 | Truy cập ngẫu nhiên lịch sử đơn của khách | Lấy N đơn mới nhất của một khách bằng một lần quét theo tiền tố khóa | 7 |
| 8 | Dashboard doanh thu – hoàn trả – giao hàng theo danh mục và tỉnh | Người không lập trình tái tạo được theo hướng dẫn | 8 |
| 9 | Mô hình hồi quy doanh thu và phân loại khả năng trả hàng | Có chỉ số R², AUC, so sánh với mô hình cơ sở | 9 |
| 10 | Khuyến nghị có căn cứ | Ít nhất 5 khuyến nghị, mỗi khuyến nghị dẫn về số liệu cụ thể | 10 |

**Mốc tham chiếu ban đầu** (tính trên 14.408 đơn sạch, [Bảng:kpi-danh-muc]):
- doanh thu ròng 78.218.341,22;
- tỷ lệ trả hàng 7,73%;
- thời gian giao trung bình 3,04 ngày.

Các khuyến nghị ở Chương 4 được đánh giá theo mức tác động lên ba chỉ số này.

**Phạm vi:**
- Dữ liệu giả lập do giảng viên cung cấp, gồm 15.000 đơn hàng (01/2025 – 07/2026), 1.200 khách hàng, 400 sản phẩm và 5.000 sự kiện.
- Hệ thống chạy trên một cụm Hadoop 4 node mô phỏng bằng Docker.
- BigSheets (IBM BigInsights) không có sẵn nên được mô phỏng quy trình.
- Kafka không nằm trong phạm vi; sự kiện được nhận qua nguồn HTTP của Flume.
