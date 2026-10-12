## 2.3. Khảo sát chất lượng dữ liệu

*[Bảng:quality-flag]. Dấu hiệu nhận biết của từng nhãn chất lượng*

| `quality_flag` | Số bản ghi | Tỷ lệ (%) | Sai công thức `net_revenue` | `delivery_days` lẻ | `delivery_days` lớn nhất | `review_score` rỗng | `campaign_id` rỗng |
|---|---:|---:|---:|---:|---:|---:|---:|
| OK | 14.095 | 93,97 | 0 | 0 | 9 | 4.983 | 0 |
| MISSING | 313 | 2,09 | 0 | 0 | 7 | 210 | 165 |
| OUTLIER | 297 | 1,98 | 219 | 71 | 37,22 | 103 | 0 |
| LATE | 146 | 0,97 | 0 | 0 | 7 | 47 | 0 |
| DUPLICATE | 149 | 0,99 | 0 | 0 | 7 | 47 | 0 |

**Nhận xét [Bảng:quality-flag]:**
- Chỉ OUTLIER có dấu hiệu rõ (sai công thức doanh thu, số ngày giao bất thường); mọi đơn thiếu `campaign_id` đều thuộc MISSING.
- LATE (nhóm hiểu là bản ghi **đến muộn** so với kỳ xử lý) và DUPLICATE không khác gì đơn OK trên mọi chỉ số, nên chỉ loại được theo nhãn.

**a) Thiếu dữ liệu**
- Chỉ `review_score` (5.390 ô, 35,93%) và `campaign_id` (165 ô, 1,10%) có ô trống. 4.983 ô trống `review_score` nằm ở đơn OK: **thiếu theo bản chất nghiệp vụ** (khách không chấm điểm), không phải lỗi.
- SQLite lưu ô trống là chuỗi rỗng `''` chứ không phải `NULL` nên `IS NULL` không bắt được.

**b) Trùng lặp**
- `record_id`, `order_id` đều duy nhất; 149 bản ghi DUPLICATE **không trùng nội dung** với bản ghi nào, nên `DISTINCT` hay khử trùng theo khóa không loại được.
- 5.000 sự kiện JSON là bản sao của 5.000 đơn đầu tiên (khớp 100% mọi trường chung); cộng dồn hai nguồn sẽ tính trùng doanh thu.

**c) Sai kiểu dữ liệu**
- Từ điển dữ liệu không chốt kiểu (`TEXT/NUMERIC`); `delivery_days` có giá trị lẻ ở OUTLIER (ví dụ 13,456).
- Tiêu đề CSV mang ký tự BOM, khiến cột đầu bị đọc thành `\ufeffrecord_id`; mọi giá trị thời gian đều đúng ISO 8601.

**d) Ngoại lệ**
- Ở nhãn OUTLIER, `unit_price` lên tới 23.600,02 (đơn sạch tối đa 3.499,94), `net_revenue` lên tới 121.652,55 (đơn sạch tối đa 21.034,66).

**e) Bản ghi không hợp lệ và không nhất quán**

Các ràng buộc miền giá trị (số lượng, đơn giá > 0; giảm giá trong [0; 1); điểm đánh giá trong [1; 5]; cờ trả ∈ {0, 1}) và toàn vẹn tham chiếu (0 khóa ngoại mồ côi) đều đạt. Các điểm không nhất quán:
- `province` của đơn khác tỉnh cư trú của khách ở 14.166/15.000 đơn (94,4%), nên hiểu là tỉnh giao hàng.
- 517 đơn mua sản phẩm có `active_flag = 0`; không có ngày ngừng bán nên chưa kết luận là lỗi.
- 117/400 sản phẩm có `list_price < unit_cost`; tỷ lệ giá niêm yết/giá vốn từ 0,03 đến 127,69.

**f) Dữ liệu luồng**
- 321/5.000 sự kiện ứng với đơn bị gắn nhãn (114 MISSING, 99 OUTLIER, 57 DUPLICATE, 51 LATE) nhưng `payload` không mang `quality_flag`; 50,27% cặp sự kiện liên tiếp sai thứ tự (mục 1.3.2).

[Bảng:yeu-cau-tien-xu-ly] tổng hợp các yêu cầu tiền xử lý; mục 2.4 thực hiện chúng.

*[Bảng:yeu-cau-tien-xu-ly]. Yêu cầu tiền xử lý*

| # | Vấn đề | Yêu cầu xử lý |
|---|---|---|
| 1 | BOM ở đầu tệp CSV | Bỏ BOM hoặc đổi tên cột đầu khi đọc |
| 2 | OUTLIER, DUPLICATE, LATE | Loại theo nhãn (592 bản ghi), còn 14.408 đơn |
| 3 | MISSING | Giữ lại; `review_score` rỗng thành NULL/NA (**không thay bằng 0**); `campaign_id` rỗng gán `NONE` |
| 4 | Ô trống `''` trong SQLite | Chuyển thành NULL/NA khi đọc |
| 5 | Kiểu chưa chốt | Khai báo schema tường minh theo [Bảng:thuoc-tinh-orders]; `delivery_days` ép về INT sau khi lọc |
| 6 | Thời gian dạng chuỗi | Chuyển thành TIMESTAMP; tạo thêm `year`, `month` (phân vùng) và `hour` |
| 7 | Nghĩa của `province` | Báo cáo là tỉnh giao hàng |
| 8 | Giá trong danh mục sản phẩm không tin cậy | Không tính lợi nhuận từ `unit_cost`, `list_price` |
| 9 | Sự kiện trùng với đơn, không mang nhãn | Khử trùng theo mã đơn (bỏ tiền tố `EVT-`) khi hợp nhất; trong luồng, gắn cờ khi `net_revenue` vượt ngưỡng theo danh mục |
| 10 | Sự kiện sai thứ tự | Xử lý theo `event_time`, có watermark cho sự kiện đến muộn |

**Nhận xét [Bảng:yeu-cau-tien-xu-ly]:** chỉ yêu cầu 2 loại bỏ bản ghi; các yêu cầu khác giữ lại dữ liệu, chỉ chuẩn hóa cách đọc, kiểu, ngữ nghĩa và cách xử lý luồng.
