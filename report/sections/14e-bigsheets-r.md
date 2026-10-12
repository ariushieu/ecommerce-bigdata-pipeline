### 1.4.4. BigSheets và R

**IBM BigSheets (mô phỏng).** BigSheets là công cụ phân tích dạng bảng tính trên web của IBM InfoSphere BigInsights [TL:ibm-bigsheets]: người dùng tạo *workbook* từ tệp HDFS, thêm *sheet* lọc, cột tính, nối, gom nhóm, bấm **Run** để sinh job chạy trên cụm Hadoop, rồi vẽ biểu đồ và ghép dashboard mà không viết mã. Vì không có BigInsights, nhóm viết hướng dẫn từng bước giao diện (`src/cau08_bigsheets/huong-dan-bigsheets.md`) và tính lại đúng từng bước bằng R kèm số liệu kiểm chứng.

**R** [TL:r-core] dùng cho phân tích Câu 9 và dashboard Câu 8: **DBI/RSQLite** [TL:dbi], [TL:rsqlite] chạy SQL có JOIN, GROUP BY và ghi kết quả về CSDL; **dplyr/tidyr** [TL:wickham-r4ds] biến đổi dữ liệu (`pivot_wider`/`pivot_longer`); **ggplot2** [TL:wickham-ggplot2] vẽ biểu đồ; **stats** (`lm`, `glm`) và **broom** [TL:broom] cho hồi quy tuyến tính và logistic [TL:islr].

*[Bảng:c09-phien-ban-r]. Phiên bản các gói R sử dụng (container `rstudio`, ảnh `rocker/tidyverse:4.4`)*

| Thành phần | Phiên bản |
|---|---|
| R | 4.4.3 |
| DBI / RSQLite (SQLite nhúng) | 1.2.3 / 2.3.9 (3.47.1) |
| dplyr / tidyr / readr | 1.1.4 / 1.3.1 / 2.1.5 |
| ggplot2 / ragg / scales | 3.5.2 / 1.3.3 / 1.3.0 |
| broom | 1.0.8 |

**Nhận xét [Bảng:c09-phien-ban-r]:**
- Mọi gói có sẵn trong ảnh Docker của nhóm (`infra/docker/r/Dockerfile`), nên người khác dựng lại được môi trường và ra cùng kết quả. Ảnh không có `patchwork` hay `pROC`, nên dashboard được ghép bằng `grid` và AUC được tính tay theo hạng.
- **Lý do chọn R:** 14.408 đơn sạch vừa bộ nhớ một máy; phần nặng về dung lượng đã do Hadoop, Pig, Spark đảm nhận, R bổ sung mô hình thống kê và trực quan hóa.
