# Hướng dẫn tái tạo phân tích bằng BigSheets (mô phỏng)

> **Phạm vi.** IBM BigSheets là công cụ phân tích dạng bảng tính chạy trên Hadoop, đi kèm IBM InfoSphere BigInsights. Môi trường của nhóm (Hadoop 3.2.2 trên Docker) **không có BigInsights**, nên các bước giao diện dưới đây là **mô phỏng**. Tên menu viết theo cách tổ chức chung của BigSheets (workbook, sheet, chart, dashboard) và có thể khác đôi chút giữa các phiên bản BigInsights.
>
> Để kết quả kiểm chứng được, **mỗi bước giao diện đều có một đoạn R/dplyr tương đương** trong `dashboard.R` (ghi mã bước B1…B9 trong chú thích). Script đã chạy thật trên 14.408 đơn sạch. Số dòng sau mỗi bước nằm trong `output/buoc_bigsheets.csv`. Người không lập trình chỉ cần so số trên màn hình BigSheets với các bảng kiểm chứng trong tài liệu này.

## 0. Chuẩn bị

| Việc | Cách làm | Kiểm tra |
|---|---|---|
| Dữ liệu trên HDFS | Câu 3 đã nạp bản chụp chuẩn bằng `bash cau03_hdfs/init_zones.sh` | `hdfs dfs -ls -R /btl/raw` có 3 tệp dưới đây |
| Tệp đơn hàng | `/btl/raw/orders/ingest_date=2026-08-01/orders.csv` | 15.000 dòng + 1 dòng tiêu đề |
| Tệp khách hàng | `/btl/raw/customers/ingest_date=2026-08-01/customers.csv` | 1.200 dòng |
| Tệp sản phẩm | `/btl/raw/products/ingest_date=2026-08-01/products.csv` | 400 dòng |
| Quyền | Tài khoản BigInsights có quyền đọc `/btl/raw` và ghi `/btl/output/cau08_bigsheets/` | |

Thuật ngữ BigSheets và câu lệnh R tương đương:

| BigSheets | Ý nghĩa | R/dplyr trong `dashboard.R` |
|---|---|---|
| Collection / master workbook | Bảng gốc đọc thẳng từ tệp trên HDFS, không sửa được | `read_csv()` |
| Reader (bộ đọc) | Cách tách cột: CSV có tiêu đề, TSV, JSON… | tham số của `read_csv()` |
| Child workbook + sheet | Chuỗi bước biến đổi, mỗi sheet là một bước | chuỗi `%>%` |
| Filter sheet | Lọc dòng theo điều kiện | `filter()` |
| Calculated column (Formula) | Cột tính bằng công thức kiểu bảng tính | `mutate()` |
| Join sheet | Nối hai workbook theo khóa | `left_join()` |
| Pivot / Group sheet | Gom nhóm và tính tổng hợp | `group_by() %>% summarise()` |
| Run | Chạy trên **toàn bộ** dữ liệu bằng job Hadoop (trước khi Run, BigSheets chỉ hiển thị kết quả trên một mẫu nhỏ) | chạy script |
| Chart, Dashboard | Biểu đồ trên workbook, ghép nhiều biểu đồ thành bảng điều khiển | `ggplot2` + `grid` |
| Export | Xuất CSV/JSON hoặc ghi lại HDFS | `write_csv()` |

## 1. Các bước

### B1. Tạo ba collection

1. Mở BigInsights Console → thẻ **BigSheets** → **New Workbook**.
2. Đặt tên `orders_raw`. Trong cây **DFS Files**, chọn `/btl/raw/orders/ingest_date=2026-08-01/orders.csv`.
3. Chọn reader **Comma-Separated Values (CSV) Data**, đánh dấu **Headers included** (dòng đầu là tiêu đề). Bấm ✓ để lưu.
4. **Xử lý BOM:** tệp CSV có ký tự BOM ở đầu, nên cột đầu có thể hiện thành `﻿record_id` (có ký tự ẩn). Nếu vậy, vào **Edit columns** đổi tên cột đầu thành `record_id`.
5. Làm tương tự cho `customers_raw` và `products_raw`.

**Kiểm chứng:** sau **Run**, góc dưới workbook hiển thị số dòng: `orders_raw` 15.000, `customers_raw` 1.200, `products_raw` 400.

### B2. Đặt kiểu cột

Trong `orders_raw` → **Build new workbook** (tạo workbook con `orders_clean`) → **Edit columns**, chọn kiểu:

| Kiểu | Cột |
|---|---|
| Number (số nguyên) | `quantity`, `returned_flag`, `review_score`, `delivery_days` |
| Number (số thực) | `unit_price`, `discount_rate`, `shipping_fee`, `net_revenue` |
| Text | các cột còn lại |

Ô trống của `review_score` và `campaign_id` **để trống**, không thay bằng 0 (quy ước nhóm). Nếu thay bằng 0, điểm đánh giá trung bình bị kéo từ 3,03 xuống 1,94 (xem Câu 9, `src/cau09_r/output/kiem_tra_o_trong.csv`).

### B3. Lọc theo chất lượng (Filter sheet)

**Add sheets → Filter**, chọn *Match all*, thêm ba điều kiện:
- `quality_flag` *is not* `OUTLIER`
- `quality_flag` *is not* `DUPLICATE`
- `quality_flag` *is not* `LATE`

Đơn `MISSING` được giữ lại. **Kiểm chứng:** 14.408 dòng, tức bỏ 592 dòng.

### B4. Cột tính toán (Calculated columns)

**Add sheets → Function/Formula** (hoặc **Insert column → Calculate**). Thêm lần lượt:

| Cột mới | Công thức kiểu BigSheets | Ý nghĩa |
|---|---|---|
| `order_month` | `=LEFT(#timestamp, 7)` | `2026-01-07T20:15:28` → `2026-01` |
| `is_late` | `=IF(#delivery_days > 5, 1, 0)` | Giao muộn > 5 ngày (P90 của thời gian giao là 5 ngày) |
| `has_campaign` | `=IF(ISNULL(#campaign_id), 0, 1)` | Đơn có mã chiến dịch |
| `revenue_bucket` | `=IF(#net_revenue < 2000, "1. < 2.000", IF(#net_revenue < 5000, "2. 2.000-5.000", IF(#net_revenue < 10000, "3. 5.000-10.000", "4. >= 10.000")))` | Nhóm giá trị đơn |

Cột được tham chiếu bằng tiền tố `#`. Tên hàm cụ thể (`LEFT`, `IF`, `ISNULL`…) nên tra lại trong danh mục hàm của phiên bản BigInsights đang dùng [TL:ibm-bigsheets]. **Kiểm chứng:** vẫn 14.408 dòng; tổng `is_late` = 1.010.

### B5. Nối với danh mục (Join sheet)

1. **Add sheets → Join**, chọn workbook `products_raw`, khóa `orders_clean.product_id = products_raw.product_id`. Giữ cột `brand`, `rating`.
2. Thêm một Join nữa với `customers_raw` theo `customer_id`. Giữ `age_group`, `province`; đổi tên `province` của khách thành `home_province` để không nhầm với tỉnh giao hàng.

**Kiểm chứng:** vẫn 14.408 dòng, không có dòng nào trống `brand` hay `age_group` (dữ liệu không có khóa mồ côi).

> `province` của đơn là **tỉnh giao hàng**. Tỉnh này khác tỉnh cư trú của khách ở 94,4% số đơn. Dashboard dùng `province` của đơn.

### B6. Nhóm và tổng hợp (Pivot/Group sheet)

Từ `orders_joined` → **Build new workbook** `dash_cat_prov` → **Add sheets → Pivot** (hoặc **Group**):
- Nhóm theo: `category`, `province`
- Cột tổng hợp:

| Cột | Phép tính |
|---|---|
| `orders` | COUNT(`order_id`) |
| `net_revenue` | SUM(`net_revenue`) |
| `returned` | SUM(`returned_flag`) |
| `avg_delivery_days` | AVERAGE(`delivery_days`) |
| `late_orders` | SUM(`is_late`) |

Sau đó thêm hai cột tính: `return_rate_pct = 100 * #returned / #orders` và `late_pct = 100 * #late_orders / #orders`.

Lặp lại để tạo các workbook `dash_category` (theo `category`), `dash_province` (theo `province`), `dash_month` (theo `order_month`) và `dash_bucket` (theo `revenue_bucket`).

**Kiểm chứng:** `dash_cat_prov` có 108 dòng (6 danh mục × 18 tỉnh). Các workbook còn lại có 6, 18, 19 và 4 dòng. Tổng cột `orders` của mỗi workbook là 14.408, tổng `returned` là 1.114.

### B7. Biểu đồ (Chart)

Trên mỗi workbook tổng hợp, chọn **Add chart** rồi **Run** để vẽ trên toàn bộ dữ liệu:

| Biểu đồ | Workbook | Kiểu | Trục |
|---|---|---|---|
| Doanh thu theo danh mục | `dash_category` | Bar (ngang) | x = `net_revenue`, y = `category`, sắp giảm dần |
| Tỷ lệ hoàn trả theo danh mục | `dash_category` | Bar | x = `return_rate_pct` |
| Thời gian giao theo tỉnh | `dash_province` | Bar (ngang) | x = `avg_delivery_days`, nhãn `late_pct` |
| Hoàn trả danh mục × tỉnh | `dash_cat_prov` | Heat map / bảng tô màu | hàng = `province`, cột = `category`, màu = `return_rate_pct` |
| Xu hướng tháng | `dash_month` | Line | x = `order_month`, y = `net_revenue` (biểu đồ thứ hai cho `return_rate_pct`, **không** gộp hai trục y) |

Nếu phiên bản BigSheets không có kiểu heat map cho dữ liệu dạng ma trận, xuất `dash_cat_prov` ra CSV rồi tô màu bằng định dạng có điều kiện trong bảng tính.

### B8. Ghép dashboard

BigInsights Console → **Dashboard** → **New dashboard** `TMDT_DoanhThu_HoanTra_GiaoHang` → **Add widget** → chọn các chart ở B7. Sắp xếp:

1. Hàng trên: 4 ô KPI là doanh thu ròng, tỷ lệ hoàn trả, thời gian giao TB, % đơn > 5 ngày. Mỗi ô lấy từ một workbook một dòng: Group không có khóa nhóm trên `orders_joined`.
2. Cột trái: heat map danh mục × tỉnh.
3. Giữa: doanh thu theo danh mục, thời gian giao theo tỉnh.
4. Phải: tỷ lệ hoàn trả theo danh mục, xu hướng tháng.

Kết quả mô phỏng: `docs/images/cau08-dashboard.png`.

### B9. Xuất kết quả và báo cáo

- **Dữ liệu:** trên mỗi workbook tổng hợp chọn **Export data → CSV**, tải về máy hoặc ghi vào `/btl/output/cau08_bigsheets/`. Tệp tương ứng của mô phỏng nằm trong `output/`: `dashboard_category_province.csv`, `dashboard_category.csv`, `dashboard_province.csv`, `dashboard_month.csv`, `dashboard_revenue_bucket.csv`, `kpi.csv`.
- **Biểu đồ:** dùng chức năng lưu ảnh của chart, hoặc chụp màn hình dashboard.
- **Báo cáo:** dán ảnh và bảng KPI vào báo cáo, ghi rõ ngày Run và bản chụp dữ liệu (`ingest_date=2026-08-01`).
- **Chạy lại khi có dữ liệu mới:** đổi đường dẫn của collection sang partition mới (**Edit → Reader settings**) rồi **Run** lại workbook gốc. Các workbook con và chart tự cập nhật theo.

## 2. Bảng kiểm chứng (số liệu thật từ `dashboard.R`)

*KPI (`output/kpi.csv`)*

| Đơn sạch | Doanh thu ròng | Đơn bị trả | Tỷ lệ trả | Giao TB | Đơn > 5 ngày |
|---:|---:|---:|---:|---:|---:|
| 14.408 | 78.218.341,22 | 1.114 | 7,73% | 3,04 ngày | 1.010 (7,01%) |

*Theo danh mục (`output/dashboard_category.csv`)*

| Danh mục | Đơn | Doanh thu ròng | % trả | Giao TB (ngày) | % > 5 ngày |
|---|---:|---:|---:|---:|---:|
| Books | 2.953 | 15.741.983,83 | 7,59 | 2,99 | 7,04 |
| Home | 2.616 | 14.257.300,58 | 7,49 | 3,05 | 6,84 |
| Electronics | 2.505 | 14.086.726,93 | 7,54 | 3,06 | 7,07 |
| Sports | 2.280 | 12.994.254,03 | 7,89 | 2,97 | 6,23 |
| Beauty | 2.219 | 11.426.625,74 | 7,62 | 3,11 | 7,30 |
| Fashion | 1.835 | 9.711.450,11 | 8,50 | 3,09 | 7,74 |

Nếu số trên BigSheets lệch so với các bảng này, kiểm tra theo thứ tự: (1) có bỏ dòng tiêu đề và BOM chưa; (2) bộ lọc B3 có đủ ba nhãn chưa; (3) `delivery_days`, `net_revenue` đã đặt kiểu số chưa (nếu để Text, SUM/AVERAGE sẽ sai).

## 3. Chạy bản mô phỏng

```bash
bash src/cau08_bigsheets/chay.sh            # trên máy thật (Git Bash), cần container rstudio đang chạy
# hoặc trong RStudio (http://localhost:8787): mở cau08_bigsheets/dashboard.R → Source
```
