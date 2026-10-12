## 1.1. Giới thiệu bài toán

Một sàn thương mại điện tử bán hàng trên ba kênh (web, ứng dụng di động, marketplace) cho khách hàng ở 18 tỉnh/thành, với 400 sản phẩm thuộc 6 nhóm hàng. Mỗi ngày sàn phát sinh hai loại dữ liệu:
- **Dữ liệu theo lô:** đơn hàng, danh mục khách hàng và sản phẩm, được xuất định kỳ từ các hệ thống nghiệp vụ.
- **Dữ liệu luồng:** các sự kiện `order_event` gửi về liên tục từ web, ứng dụng, API và đối tác.

Hai loại dữ liệu này hiện nằm rời rạc ở nhiều định dạng (CSV, JSON, LOG, SQLite) và chứa một phần bản ghi lỗi. Vì vậy sàn chưa trả lời nhanh và chính xác được các câu hỏi vận hành cơ bản, ví dụ:
- Nhóm hàng và tỉnh nào mang lại doanh thu cao nhất?
- Tỷ lệ trả hàng ở đâu đang cao?
- Đơn hàng mất bao lâu để giao tới khách?

**Đối tượng sử dụng** kết quả của hệ thống:

*[Bảng:doi-tuong-su-dung]. Đối tượng sử dụng và nhu cầu thông tin*

| Đối tượng | Nhu cầu thông tin | Tần suất |
|---|---|---|
| Ban điều hành | Doanh thu, tỷ lệ hoàn trả, thời gian giao theo tháng; xu hướng tăng trưởng | Hằng tuần, hằng tháng |
| Bộ phận kinh doanh, marketing | Sản phẩm tăng trưởng nhanh, khách hàng có nguy cơ rời bỏ, hiệu quả theo phân khúc và kênh | Hằng tuần |
| Bộ phận vận hành, giao nhận | Thời gian giao theo tỉnh, cảnh báo tỷ lệ trả tăng đột biến | Hằng ngày, gần thời gian thực |
| Chăm sóc khách hàng | Lịch sử đơn mới nhất của một khách | Tức thời (truy cập ngẫu nhiên) |
| Nhóm dữ liệu | Chất lượng dữ liệu, tính nhất quán giữa dữ liệu lô và luồng | Mỗi lần nạp |

**Nhận xét [Bảng:doi-tuong-su-dung]:** các nhu cầu khác nhau rất xa về độ trễ, từ hằng tháng tới tức thời. Hệ thống vì thế phải có cả nhánh xử lý theo lô lẫn nhánh xử lý gần thời gian thực (mục 1.3.7).

**Vấn đề cần giải quyết:** xây dựng một nền tảng phân tích tích hợp với các chức năng sau:
- thu thập cả dữ liệu lô và dữ liệu luồng;
- lưu trữ phân tán, có phân vùng;
- làm sạch theo quy tắc thống nhất;
- xử lý bằng nhiều công cụ của hệ sinh thái Hadoop (Pig, MapReduce, Spark, HBase), cho kết quả khớp nhau;
- trực quan hóa và phân tích thống kê để đưa ra khuyến nghị.
