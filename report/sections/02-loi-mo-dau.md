# LỜI MỞ ĐẦU

Thương mại điện tử Việt Nam đã trở thành một kênh bán lẻ chủ lực. Mỗi đơn hàng trên một sàn thương mại điện tử không chỉ là một giao dịch, mà còn để lại dấu vết dữ liệu: khách đặt hàng từ kênh nào, mua nhóm hàng gì, giao tới tỉnh nào, mất bao nhiêu ngày, có trả lại hay không, đánh giá ra sao. Khi dữ liệu này được thu thập đầy đủ và phân tích đúng cách, sàn có thể trả lời những câu hỏi quyết định lợi nhuận:
- nên đẩy mạnh nhóm hàng nào;
- vì sao khách trả hàng;
- tỉnh nào đang giao chậm;
- khách hàng nào sắp rời bỏ.

Khó khăn nằm ở đặc điểm của dữ liệu.
- **Dữ liệu đến từ nhiều nguồn và ở nhiều định dạng:** web, ứng dụng di động, API, đối tác và các tệp xuất theo lô; ở dạng CSV, JSON, nhật ký (LOG) và cơ sở dữ liệu quan hệ.
- **Dữ liệu đến theo hai nhịp khác nhau:** đơn hàng được tổng hợp theo lô, còn sự kiện mua sắm đổ về liên tục và không theo thứ tự thời gian.
- **Dữ liệu không hoàn toàn sạch:** có bản ghi thiếu, bản ghi ngoại lệ, bản ghi trùng và bản ghi đến muộn.

Đây là những đặc trưng điển hình của dữ liệu lớn (Big Data), và một cơ sở dữ liệu truyền thống trên một máy chủ khó đáp ứng khi quy mô tăng lên.

Đề tài **"Phân tích hành vi mua sắm và vận hành thương mại điện tử"** (Đề 01, học phần Xử lý dữ liệu lớn – CTKU122) đặt ra yêu cầu xây dựng một nền tảng phân tích tích hợp dữ liệu đơn hàng theo lô và sự kiện mua sắm thời gian thực, nhằm **tối ưu doanh thu, tỷ lệ hoàn trả và thời gian giao hàng**. Nhóm chọn đề tài này vì ba lý do:
- Bài toán gần với thực tế vận hành của các sàn thương mại điện tử.
- Đề tài đòi hỏi kết hợp gần như toàn bộ hệ sinh thái Hadoop đã học: Flume, HDFS, YARN, Pig, MapReduce, Spark, HBase, cùng BigSheets và R.
- Bộ dữ liệu có chủ đích chứa lỗi, buộc nhóm phải thực hành đầy đủ quy trình đánh giá và làm sạch dữ liệu.

Trong phạm vi bài tập lớn, nhóm đã:
1. Phân tích đặc trưng 5V và chất lượng của bộ dữ liệu bằng số liệu đo trực tiếp.
2. Thiết kế kiến trúc thu thập – lưu trữ đầu–cuối, gồm hai kịch bản Flume và bốn vùng dữ liệu trên HDFS.
3. Hiện thực cùng một phép tính (doanh thu và tỷ lệ trả hàng) bằng ba công cụ Pig, MapReduce và Spark, rồi đối chiếu kết quả và hiệu năng.
4. Xây dựng pipeline Spark tìm sản phẩm tăng trưởng nhanh và khách hàng có nguy cơ rời bỏ.
5. Thiết kế bảng HBase cho truy cập ngẫu nhiên theo khách hàng.
6. Mô phỏng quy trình BigSheets và dựng dashboard.
7. Dùng R với SQLite để xây dựng mô hình hồi quy và phân loại.

Toàn bộ hệ thống chạy trên một cụm Hadoop 4 node (1 master, 3 worker). Mã nguồn được kiểm thử tự động, nên kết quả có thể tái lập.

Báo cáo gồm năm chương:
- **Chương 1** trình bày tổng quan bài toán, đặc trưng Big Data và kiến trúc hệ thống.
- **Chương 2** mô tả dữ liệu, khảo sát chất lượng và tiền xử lý.
- **Chương 3** trình bày việc xây dựng hệ thống xử lý.
- **Chương 4** trình bày kết quả, trực quan hóa và đánh giá hiệu năng.
- **Chương 5** tổng kết, nêu hạn chế và hướng phát triển.

Mặc dù đã cố gắng, báo cáo khó tránh khỏi thiếu sót do hạn chế về thời gian và kinh nghiệm. Nhóm rất mong nhận được ý kiến góp ý của thầy cô để hoàn thiện hơn.

Nhóm xin chân thành cảm ơn!
