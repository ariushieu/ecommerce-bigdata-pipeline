## 4.3. Trực quan hóa

Các hình vẽ bằng ggplot2 [TL:wickham-ggplot2]: màu cam đánh dấu nhóm cao hơn trung bình, nét đứt là trung bình chung; dashboard Câu 8 mô phỏng các bước BigSheets B1–B8 (mục 1.4.4).

### 4.3.1. Dashboard doanh thu – hoàn trả – giao hàng

![](../../docs/images/cau08-dashboard.png){width=100%}

*[Hình:c08-dashboard]. Dashboard tổng hợp theo danh mục và tỉnh giao hàng (mô phỏng BigSheets bằng R/ggplot2)*

**Nhận xét [Hình:c08-dashboard]:**
- Hàng KPI trả lời ba mục tiêu (mục 1.3.5); 5 biểu đồ ghép bằng `grid` (bước B8) đi sâu theo **danh mục**, **tỉnh giao hàng** và tháng.
- Books dẫn đầu với 15,74 triệu (20,1% doanh thu), Fashion thấp nhất với 9,71 triệu, chủ yếu do **số đơn** (2.953 so với 1.835 đơn). Fashion cũng trả nhiều nhất (8,50%, trung bình 7,73%), nhưng χ² theo danh mục cho p = 0,839 ([Bảng:c09-kiem-dinh]), nên cần thí điểm biện pháp rồi đo lại.

### 4.3.2. Doanh thu và hoàn trả theo danh mục

![](../../docs/images/cau09-doanh-thu-danh-muc-phan-khuc.png)

*[Hình:c09-doanh-thu-phan-khuc]. Doanh thu ròng theo danh mục và phân khúc khách hàng (kết quả truy vấn SQL JOIN + GROUP BY trong R)*

**Nhận xét [Hình:c09-doanh-thu-phan-khuc]:** Hình vẽ kết quả truy vấn JOIN 3 bảng của Câu 9 (trùng với kết quả Pig ở mục 4.1). Bốn phân khúc đóng góp gần bằng nhau trong mỗi danh mục; riêng Fashion – Loyal vừa có doanh thu thấp nhất vừa trả nhiều nhất (9,47%, [Bảng:c09-ma-tran-tra]), nên khảo sát lý do trả.

### 4.3.3. Theo tỉnh giao hàng

![](../../docs/images/cau08-heatmap-hoan-tra.png)

*[Hình:c08-heatmap-hoan-tra]. Ma trận tỷ lệ hoàn trả (%) theo danh mục × tỉnh giao hàng*

**Nhận xét [Hình:c08-heatmap-hoan-tra]:** Ma trận trông có "điểm nóng" (Fashion – Quang Nam 12,7%) và ô rất thấp (Beauty – Nghe An 1,7%), nhưng mỗi ô chỉ có 87–185 đơn và χ² trên 108 ô cho p = 0,529, tức mức phân tán **đúng bằng kỳ vọng nếu chỉ có ngẫu nhiên**. Chỉ nên cảnh báo khi một ô vượt ngưỡng nhiều kỳ liên tiếp.

*[Bảng:c08-tinh]. Tỉnh giao hàng có chỉ số giao hàng cao nhất và thấp nhất (`dashboard_province.csv`, 18 tỉnh)*

| Chỉ số | Cao nhất | Thấp nhất | Toàn bộ |
|---|---|---|---|
| Giao trung bình | Lam Dong 3,14 ngày | Binh Duong 2,95 ngày | 3,04 ngày |
| % đơn giao > 5 ngày | TP Ho Chi Minh 8,21% | Quang Ninh 5,48% | 7,01% |

**Nhận xét [Bảng:c08-tinh]:** Thời gian giao trung bình chỉ chênh 0,19 ngày giữa các tỉnh (ANOVA p = 0,611), nhưng tỷ lệ đơn trễ chênh nhiều hơn (TP Ho Chi Minh, Lam Dong, Thanh Hoa khoảng 8%). Vì vậy cần theo dõi **% đơn trễ** theo tỉnh thay cho số ngày trung bình.

### 4.3.4. Xu hướng theo tháng và nhóm giá trị đơn

![](../../docs/images/cau08-xu-huong-thang.png){width=70%}

*[Hình:c08-xu-huong-thang]. Doanh thu ròng (triệu) và tỷ lệ hoàn trả (%) theo tháng, 01/2025 – 07/2026*

**Nhận xét [Hình:c08-xu-huong-thang]:** Doanh thu tháng dao động 3,65–4,50 triệu (thấp nhất 02/2026 do tháng ngắn), không có xu hướng dài hạn. Tỷ lệ trả dao động 5,75% (07/2025) – 10,25% (05/2026); bốn tháng 03–06/2026 đều trên 8%.

*[Bảng:c08-nhom-gia-tri]. Đóng góp theo nhóm giá trị đơn (`dashboard_revenue_bucket.csv`, cột tính `revenue_bucket` ở bước B4)*

| Nhóm giá trị đơn | Số đơn | Doanh thu ròng | % trả | % đơn > 5 ngày |
|---|---:|---:|---:|---:|
| < 2.000 | 2.729 | 3.496.280,32 | 7,51 | 7,37 |
| 2.000–5.000 | 5.027 | 17.098.262,35 | 8,20 | 6,52 |
| 5.000–10.000 | 4.786 | 34.033.479,44 | 7,56 | 7,48 |
| ≥ 10.000 | 1.866 | 23.590.319,11 | 7,23 | 6,59 |

**Nhận xét [Bảng:c08-nhom-gia-tri]:** Đơn từ 10.000 trở lên chỉ chiếm 12,95% số đơn nhưng mang lại 30,16% doanh thu, và tỷ lệ trả của nhóm này (7,23%) không cao hơn nhóm khác: tăng giá trị giỏ hàng (mục 4.2.4) không làm tăng rủi ro hoàn trả.

### 4.3.5. Tỷ lệ hoàn trả theo từng yếu tố

![](../../docs/images/cau09-tra-hang-theo-yeu-to.png)

*[Hình:c09-tra-theo-yeu-to]. Tỷ lệ hoàn trả theo 7 yếu tố, kèm khoảng tin cậy 95% (dữ liệu dạng dài tạo bằng `pivot_longer`)*

**Nhận xét [Hình:c09-tra-theo-yeu-to]:** Ở cả 7 yếu tố, **khoảng tin cậy 95% của mọi mức đều cắt đường trung bình 7,73%** (tách xa nhất là kênh marketplace, 7,10%, khoảng 6,37–7,82%). Vì vậy mô hình phân loại ở mục 4.2.5 không học được.
