### 1.4.4. BigSheets và R

**IBM BigSheets (mô phỏng).** BigSheets là công cụ bảng tính trên web của IBM InfoSphere BigInsights [TL:ibm-bigsheets]: người dùng tạo *workbook* từ tệp HDFS, thêm *sheet* lọc, cột tính, nối, gom nhóm, bấm **Run** để sinh job chạy trên cụm Hadoop, rồi vẽ biểu đồ và ghép dashboard mà không viết mã. Vì không có BigInsights, nhóm viết hướng dẫn từng bước giao diện (`src/cau08_bigsheets/huong-dan-bigsheets.md`) và tính lại đúng từng bước bằng R.

**R** [TL:r-core] dùng cho Câu 8 và Câu 9: **DBI/RSQLite** [TL:dbi], [TL:rsqlite] chạy SQL và ghi kết quả về CSDL; **dplyr/tidyr** [TL:wickham-r4ds] biến đổi dữ liệu; **ggplot2** [TL:wickham-ggplot2] vẽ biểu đồ; **stats** và **broom** [TL:broom] cho hồi quy tuyến tính và logistic [TL:islr]. Nhóm chọn R vì 14.408 đơn sạch vừa bộ nhớ một máy, còn phần nặng về dung lượng đã do Hadoop, Pig, Spark đảm nhận. Phiên bản các gói ở [Bảng:c09-phien-ban-r] (Phụ lục B, mã nguồn E).
