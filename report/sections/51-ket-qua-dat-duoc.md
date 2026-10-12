## 5.1. Kết quả đạt được

Nhóm đã xây dựng một nền tảng phân tích dữ liệu lớn hoàn chỉnh cho bài toán thương mại điện tử, chạy trên cụm Hadoop 4 node và tái lập được bằng Docker. Các kết quả chính:

1. **Hiểu dữ liệu bằng số liệu.**
   - Phân tích 5V và Variability trên dữ liệu thật.
   - Phân loại 6 tệp và 47 trường thành có cấu trúc, bán cấu trúc và luồng.
   - Phát hiện các lỗi dữ liệu không nằm trong nhãn `quality_flag`: SQLite lưu ô trống là `''`, giá trong danh mục sản phẩm không nhất quán, sự kiện đến sai thứ tự.
2. **Thu thập và lưu trữ.**
   - Hai kịch bản Flume: CSV theo lô vào HDFS; sự kiện qua HTTP vào đồng thời HDFS và HBase.
   - Thực nghiệm chứng minh FileChannel không mất sự kiện khi agent bị tắt đột ngột.
   - Bốn vùng dữ liệu raw/staging/curated/output trên HDFS, nhân bản 3 lần, chịu được việc hỏng một node.
3. **Xử lý bằng ba công cụ cho cùng một kết quả.**
   - Pig, MapReduce (có Combiner và Partitioner tự viết) và Spark cùng tính doanh thu và tỷ lệ trả. Kết quả trùng nhau tới từng byte trên 114 ô và khớp số liệu profiling.
   - Phép đối chiếu chạy tự động trong CI.
4. **Phân tích nghiệp vụ.**
   - Spark xác định 64 sản phẩm tăng trưởng nhanh và 369 khách có nguy cơ rời bỏ.
   - HBase cho phép lấy lịch sử đơn mới nhất của một khách bằng một lần quét theo tiền tố khóa.
   - Dashboard doanh thu – hoàn trả – giao hàng kèm hướng dẫn BigSheets cho người không lập trình.
   - R xây dựng mô hình hồi quy doanh thu (R² = 0,833) và đánh giá trung thực mô hình phân loại hoàn trả.
5. **Khuyến nghị:** 7 khuyến nghị có căn cứ, gắn với ba mục tiêu doanh thu, hoàn trả và giao hàng (mục 4.5.4).
6. **Tái lập và kiểm thử.**
   - Môi trường, mã nguồn, dữ liệu và báo cáo nằm trong một kho mã.
   - Mỗi câu có `test.sh` chạy trên cụm thật trong GitHub Actions.
   - Báo cáo Word được ghép tự động từ các mục Markdown.
