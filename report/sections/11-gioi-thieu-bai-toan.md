## 1.1. Giới thiệu bài toán

Một sàn thương mại điện tử bán trên ba kênh (web, ứng dụng di động, marketplace) cho khách ở 18 tỉnh/thành, với 400 sản phẩm thuộc 6 nhóm hàng. Sàn phát sinh hai loại dữ liệu: **dữ liệu theo lô** (đơn hàng, danh mục khách hàng và sản phẩm, xuất định kỳ từ hệ thống nghiệp vụ) và **dữ liệu luồng** (sự kiện `order_event` gửi liên tục từ web, ứng dụng, API và đối tác).

Dữ liệu nằm rời rạc ở nhiều định dạng (CSV, JSON, LOG, SQLite), có bản ghi lỗi, nên sàn chưa trả lời nhanh được: nhóm hàng, tỉnh nào doanh thu cao nhất; tỷ lệ trả cao ở đâu; giao hàng mất bao lâu.

*[Bảng:doi-tuong-su-dung]. Đối tượng sử dụng và nhu cầu thông tin*

| Đối tượng | Nhu cầu thông tin | Tần suất |
|---|---|---|
| Ban điều hành | Doanh thu, tỷ lệ hoàn trả, thời gian giao theo tháng | Hằng tuần, hằng tháng |
| Kinh doanh, marketing | Sản phẩm tăng trưởng nhanh, khách có nguy cơ rời bỏ | Hằng tuần |
| Vận hành, giao nhận | Thời gian giao theo tỉnh, cảnh báo tỷ lệ trả tăng đột biến | Hằng ngày, gần thời gian thực |
| Chăm sóc khách hàng | Lịch sử đơn mới nhất của một khách | Tức thời |
| Nhóm dữ liệu | Chất lượng, tính nhất quán giữa dữ liệu lô và luồng | Mỗi lần nạp |

**Nhận xét [Bảng:doi-tuong-su-dung]:** độ trễ yêu cầu trải từ hằng tháng tới tức thời, nên hệ thống cần cả nhánh lô lẫn nhánh gần thời gian thực (mục 1.3.7).

**Vấn đề cần giải quyết:** xây dựng nền tảng phân tích tích hợp, thu thập cả dữ liệu lô và luồng, lưu trữ phân tán có phân vùng, làm sạch theo quy tắc thống nhất, xử lý bằng Pig, MapReduce, Spark, HBase cho kết quả khớp nhau, rồi trực quan hóa và phân tích thống kê để đưa ra khuyến nghị.
