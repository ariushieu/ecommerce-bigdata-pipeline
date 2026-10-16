## 2.3. Khảo sát chất lượng dữ liệu

*[Bảng:quality-flag]. Dấu hiệu nhận biết của từng nhãn chất lượng*

| Nhãn | Số bản ghi | Tỷ lệ (%) | Sai công thức doanh thu | Ngày giao lẻ | Ngày giao lớn nhất | Thiếu điểm đánh giá | Thiếu mã chiến dịch |
|---|---:|---:|---:|---:|---:|---:|---:|
| OK | 14.095 | 93,97 | 0 | 0 | 9 | 4.983 | 0 |
| MISSING | 313 | 2,09 | 0 | 0 | 7 | 210 | 165 |
| OUTLIER | 297 | 1,98 | 219 | 71 | 37,22 | 103 | 0 |
| LATE | 146 | 0,97 | 0 | 0 | 7 | 47 | 0 |
| DUPLICATE | 149 | 0,99 | 0 | 0 | 7 | 47 | 0 |

**Nhận xét [Bảng:quality-flag]:** chỉ OUTLIER có dấu hiệu rõ (sai công thức doanh thu, số ngày giao bất thường); mọi đơn thiếu `campaign_id` thuộc MISSING. LATE (bản ghi **đến muộn**) và DUPLICATE giống hệt đơn OK nên chỉ loại được theo nhãn.

**a) Thiếu dữ liệu:** chỉ `review_score` (35,93%) và `campaign_id` (1,10%) có ô trống; 4.983 ô trống `review_score` nằm ở đơn OK, tức **thiếu theo bản chất nghiệp vụ**. SQLite lưu ô trống là chuỗi `''` nên `IS NULL` không bắt được.

**b) Trùng lặp:** `order_id` duy nhất; 149 bản ghi DUPLICATE **không trùng nội dung** với bản ghi nào nên `DISTINCT` không loại được. 5.000 sự kiện JSON là bản sao của 5.000 đơn đầu tiên; cộng dồn hai nguồn sẽ tính trùng doanh thu.

**c) Sai kiểu:** từ điển không chốt kiểu; `delivery_days` có giá trị lẻ ở OUTLIER (ví dụ 13,456); dòng tiêu đề CSV mang ký tự BOM (U+FEFF) khiến tên cột đầu bị đọc sai nếu không xử lý.

**d) Ngoại lệ:** ở OUTLIER, `unit_price` lên tới 23.600,02 và `net_revenue` tới 121.652,55 (đơn sạch tối đa 3.499,94 và 21.034,66).

**e) Không hợp lệ, không nhất quán:** các ràng buộc miền giá trị và toàn vẹn tham chiếu đều đạt. Tuy nhiên `province` khác tỉnh cư trú ở 94,4% đơn (hiểu là tỉnh giao hàng); 517 đơn mua sản phẩm `active_flag = 0`; 117/400 sản phẩm có `list_price < unit_cost`.

**f) Dữ liệu luồng:** 321/5.000 sự kiện ứng với đơn bị gắn nhãn nhưng `payload` không mang `quality_flag`; 50,27% cặp liên tiếp sai thứ tự (mục 1.3.2).

*[Bảng:yeu-cau-tien-xu-ly]. Yêu cầu tiền xử lý*

| # | Vấn đề | Yêu cầu xử lý |
|---|---|---|
| 1 | BOM ở đầu tệp CSV | Bỏ BOM hoặc đổi tên cột đầu |
| 2 | OUTLIER, DUPLICATE, LATE | Loại theo nhãn (592 bản ghi), còn 14.408 đơn |
| 3 | MISSING | Giữ; `review_score` rỗng thành NULL (**không thay bằng 0**); `campaign_id` rỗng gán `NONE` |
| 4 | Ô trống `''` trong SQLite | Chuyển thành NULL/NA khi đọc |
| 5 | Kiểu chưa chốt | Schema tường minh theo [Bảng:thuoc-tinh-orders]; `delivery_days` ép INT sau khi lọc |
| 6 | Thời gian dạng chuỗi | Chuyển TIMESTAMP; tạo `year`, `month`, `hour` |
| 7 | Nghĩa của `province` | Báo cáo là tỉnh giao hàng |
| 8 | Giá sản phẩm không tin cậy | Không tính lợi nhuận từ `unit_cost`, `list_price` |
| 9 | Sự kiện trùng đơn, không mang nhãn | Khử trùng theo mã đơn khi hợp nhất; trong luồng, gắn cờ khi `net_revenue` vượt ngưỡng |
| 10 | Sự kiện sai thứ tự | Xử lý theo `event_time`, có watermark |

**Nhận xét [Bảng:yeu-cau-tien-xu-ly]:** chỉ yêu cầu 2 loại bỏ bản ghi, các yêu cầu khác chỉ chuẩn hóa cách đọc, kiểu, ngữ nghĩa (thực hiện ở mục 2.4).
