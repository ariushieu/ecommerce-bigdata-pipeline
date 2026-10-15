## 5.1. Kết quả đạt được

Nhóm đã xây dựng một nền tảng phân tích dữ liệu lớn hoàn chỉnh cho bài toán thương mại điện tử, chạy trên cụm Hadoop 4 node và tái lập được bằng Docker. Các kết quả chính:

1. **Hiểu dữ liệu bằng số liệu:** phân tích 5V và Variability; phân loại 6 tệp, 47 trường; phát hiện các lỗi nằm ngoài nhãn `quality_flag` (ô trống `''` trong SQLite, giá sản phẩm không nhất quán, sự kiện sai thứ tự).
2. **Thu thập và lưu trữ:** hai kịch bản Flume (CSV theo lô; sự kiện HTTP vào đồng thời HDFS và HBase), FileChannel không mất sự kiện khi agent bị tắt đột ngột; bốn vùng dữ liệu trên HDFS nhân bản 3 lần, chịu được hỏng một node.
3. **Ba công cụ cho cùng một kết quả:** Pig, MapReduce (Combiner, Partitioner tự viết) và Spark trùng nhau tới từng byte trên 114 ô, khớp profiling; phép đối chiếu chạy tự động trong CI.
4. **Phân tích nghiệp vụ:** 64 sản phẩm tăng trưởng nhanh, 369 khách nguy cơ rời bỏ; tra cứu lịch sử đơn bằng HBase; dashboard kèm hướng dẫn BigSheets; hồi quy doanh thu R² = 0,833 và đánh giá trung thực mô hình phân loại hoàn trả.
5. **Khuyến nghị:** 7 khuyến nghị có căn cứ, gắn với ba mục tiêu (mục 4.5.4).
6. **Tái lập và kiểm thử:** môi trường, mã nguồn, dữ liệu và báo cáo trong một kho mã; mỗi câu có `test.sh` chạy trên cụm thật trong GitHub Actions.
