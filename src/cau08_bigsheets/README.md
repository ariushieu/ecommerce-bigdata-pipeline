# Câu 8 – Mô phỏng BigSheets + dashboard

**Yêu cầu:** Collection, làm sạch, calculated columns, lọc/nhóm/join, dashboard doanh thu – hoàn trả – giao hàng theo danh mục và tỉnh; hướng dẫn từng bước cho người không lập trình.

**Phụ trách:** thành viên E (xem [phân công](../../README.md#phân-công-mỗi-người-20)). Quy ước chung: [`docs/quy-uoc.md`](../../docs/quy-uoc.md).

**Bài viết:** mục 1.4.4, 4.3 và Phụ lục C của báo cáo (`report/sections/14e-*.md`, `43-*.md`, `97-*.md`).

IBM BigSheets (thuộc BigInsights) không có trong môi trường của nhóm. Vì vậy Câu 8 gồm hai phần:
1. [`huong-dan-bigsheets.md`](huong-dan-bigsheets.md): các bước giao diện BigSheets từ B1 đến B9, viết cho người không lập trình, kèm bảng số liệu kiểm chứng.
2. `dashboard.R`: tính lại **đúng từng bước đó** bằng R/dplyr trên 14.408 đơn sạch, rồi vẽ dashboard bằng ggplot2.

## Chạy

```bash
# Trên máy thật (Git Bash), container rstudio đang chạy:
bash src/cau08_bigsheets/chay.sh
#   = docker exec rstudio Rscript /home/rstudio/src/cau08_bigsheets/dashboard.R
#     + chuyển ảnh output/hinh/cau08-*.png sang docs/images/ (container không gắn docs/)

# Kiểm tra (CI chạy trong may1, không cần R):
ssh may1
cd ~/src/cau08_bigsheets && bash test.sh
```

Có thể chạy trong RStudio (http://localhost:8787): mở `cau08_bigsheets/dashboard.R` rồi bấm **Source**. Khi đó ảnh nằm ở `output/hinh/`, cần tự chép sang `docs/images/`.

| Tệp | Nội dung |
|---|---|
| `huong-dan-bigsheets.md` | Hướng dẫn BigSheets: collection, reader CSV/BOM, Filter, calculated columns, Join, Pivot, chart, dashboard, export |
| `dashboard.R` | Mô phỏng các bước B1–B8 bằng readr/dplyr/tidyr, vẽ 5 biểu đồ và 1 dashboard ghép bằng `grid` (ảnh R không có patchwork/gridExtra) |
| `chay.sh` | Chạy script trong container rstudio, chuyển ảnh sang `docs/images/` |
| `test.sh` | Tính lại từng ô danh mục × tỉnh từ `/data/orders.csv` bằng Python thư viện chuẩn, so với `output/`; kiểm tra KPI và tổng các bảng |
| `output/kpi.csv` | 4 KPI: doanh thu, tỷ lệ trả, giao TB, % đơn > 5 ngày |
| `output/dashboard_category_province.csv` | Bảng chính của dashboard: 108 ô danh mục × tỉnh giao hàng (đơn, doanh thu, trả, % trả, giao TB, đơn trễ, % trễ) |
| `output/dashboard_{category,province,month,revenue_bucket}.csv` | Các bảng tổng hợp theo một chiều |
| `output/buoc_bigsheets.csv` | Số dòng sau mỗi bước, để so với số dòng BigSheets hiển thị |
| `output/log_chay.txt` | Log lần chạy gần nhất |
| `docs/images/cau08-*.png` | `dashboard`, `doanh-thu-danh-muc`, `hoan-tra-danh-muc`, `giao-hang-tinh`, `heatmap-hoan-tra`, `xu-huong-thang` |

## Ghi chú kỹ thuật

- Làm sạch theo quy ước chung: bỏ `quality_flag` ∈ {OUTLIER, DUPLICATE, LATE}, giữ MISSING, còn 14.408 đơn. `readr` tự bỏ BOM; script dừng lại nếu cột đầu không phải `record_id`.
- `province` là **tỉnh giao hàng**. Tỉnh cư trú của khách được join vào với tên `home_province`.
- "Giao trễ" được định nghĩa là `delivery_days > 5` (P90 = 5 ngày, theo Câu 1).
- Font biểu đồ là **TeX Gyre Heros** (có sẵn trong ảnh rocker, đủ dấu tiếng Việt); nếu không có thì script lùi về DejaVu Sans/Noto Sans/sans. Ảnh xuất bằng `ragg`, 150 dpi.
- Số liệu nhất quán với Câu 1 (`src/cau01_5v/output/profile.md`): 14.408 đơn, doanh thu 78.218.341,22, 1.114 đơn trả (7,73%), giao TB 3,04 ngày, 7,01% đơn > 5 ngày.
