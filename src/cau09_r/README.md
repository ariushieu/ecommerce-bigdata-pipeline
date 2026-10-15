# Câu 9 – R + SQLite

**Yêu cầu:** DBI/RSQLite, SQL có JOIN + GROUP BY, dplyr/tidyr, ggplot2, hồi quy doanh thu, phân loại khả năng trả hàng, ghi kết quả lại CSDL (bản copy), đóng kết nối.

**Phụ trách:** Phạm Văn Quyết – thành viên E (xem [phân công](../../README.md#phân-công-mỗi-người-20)). Quy ước chung: [`docs/quy-uoc.md`](../../docs/quy-uoc.md).

**Bài viết:** mục 1.4.4, 4.2 (phần Câu 9), 4.3 và Phụ lục B/C của báo cáo.

## Chạy

```bash
# Trên máy thật (Git Bash), container rstudio đang chạy:
bash src/cau09_r/chay.sh
#   = docker exec rstudio Rscript /home/rstudio/src/cau09_r/phan_tich.R  (khoảng 15 giây)
#     + chuyển ảnh output/hinh/cau09-*.png sang docs/images/

# Kiểm tra (CI chạy trong may1, không cần R):
ssh may1
cd ~/src/cau09_r && bash test.sh
```

Có thể chạy trong RStudio (http://localhost:8787): mở `cau09_r/phan_tich.R` rồi bấm **Source**.

## Script `phan_tich.R` làm gì

| Bước | Nội dung |
|---|---|
| 1. Kết nối | `/data` chỉ đọc, nên script copy `project_data.sqlite` sang `output/project_data_results.sqlite` (gitignore) rồi `dbConnect()` vào bản copy. `on.exit(dbDisconnect(con), add = TRUE)` đặt trong `main()`, nên kết nối luôn được đóng, kể cả khi có lỗi giữa chừng. Sau khi `main()` kết thúc, script kiểm tra `dbIsValid(con) == FALSE`. |
| 2. SQL | (a) Kiểm tra ô trống `''`; (b) JOIN `fact_main` – `item_master` – `entity_master`, GROUP BY danh mục × phân khúc; (c) GROUP BY khách hàng; (d) JOIN mức đơn để mô hình hóa. Ô trống được đổi thành NULL bằng `NULLIF(…, '')` ngay trong SQL. |
| 3. dplyr/tidyr | `pivot_wider` tạo ma trận tỷ lệ trả danh mục × phân khúc. `pivot_longer` đưa 7 yếu tố về dạng dài để tính tỷ lệ trả, khoảng tin cậy 95% và kiểm định χ² |
| 4. Hồi quy | Chia train/test 70/30 (`set.seed(2026)`, phân tầng theo `returned_flag`); so sánh M0–M4; mô hình chính M3 là `log(net_revenue)` theo danh mục, phân khúc, kênh, thanh toán, chiến dịch, giảm giá, `log(quantity)`, `log(list_price)`. Dùng `broom::tidy/glance/augment` và kiểm tra phần dư |
| 5. Phân loại | `glm(binomial)` dự báo `returned_flag`; ma trận nhầm lẫn ở ngưỡng 0,5 và ngưỡng Youden (chọn trên train); so với baseline đa số; AUC tính tay theo hạng (Mann–Whitney), không dùng pROC; kiểm định tỷ số hợp lý; bảng thập phân vị |
| 6. Ghi lại CSDL | 16 bảng `kq_*` ghi bằng `dbWriteTable(overwrite = TRUE)`, rồi đọc lại `COUNT(*)` từ SQLite để xác nhận: xem `output/bang_ghi_lai_csdl.txt` |
| 7. ggplot2 | 5 ảnh `docs/images/cau09-*.png` |

## Tệp

| Tệp | Nội dung |
|---|---|
| `phan_tich.R` | Toàn bộ phân tích |
| `chay.sh` | Chạy trong container và chuyển ảnh sang `docs/images/` |
| `test.sh` | Chạy lại truy vấn JOIN + GROUP BY bằng `sqlite3` của Python, so với CSV; kiểm tra tính nhất quán của kết quả mô hình; nếu có CSDL kết quả thì kiểm tra số dòng các bảng `kq_*` (CI không có tệp này nên bỏ qua) |
| `output/tong_hop_danh_muc_phan_khuc.csv` | Kết quả SQL JOIN + GROUP BY (24 nhóm) |
| `output/kiem_tra_o_trong.csv` | Số ô `''` và sai lệch khi tính AVG mà không dùng NULLIF |
| `output/ma_tran_ty_le_tra.csv`, `ma_tran_doanh_thu.csv` | Ma trận tạo bằng `pivot_wider` |
| `output/tra_theo_yeu_to.csv`, `kiem_dinh_chi2.csv`, `kiem_dinh_giao_hang.csv` | Tỷ lệ trả theo yếu tố (có KTC 95%), kiểm định χ², ANOVA thời gian giao |
| `output/hoi_quy_*.csv` | So sánh mô hình, hệ số M3, ANOVA, phần dư, mô hình mức khách hàng |
| `output/phan_loai_*.csv` | Chỉ số phân loại, hệ số/odds ratio, kiểm định tỷ số hợp lý, thập phân vị |
| `output/bang_ghi_lai_csdl.{txt,csv}` | Danh sách bảng đã ghi lại CSDL kèm số dòng |
| `output/log_chay.txt` | Log lần chạy gần nhất |
| `output/project_data_results.sqlite` | CSDL kết quả (không commit, chạy lại để tạo) |

## Lưu ý dữ liệu

- **Ô trống trong SQLite là `''`, không phải NULL.** Cột `review_score` khai báo INTEGER nhưng chứa `''`, nên khi đọc nguyên cột, RSQLite đổi `''` thành **0** mà chỉ cảnh báo, còn `AVG(review_score)` trong SQLite cũng coi `''` là 0. Hậu quả là điểm TB sai thành 1,94 thay vì 3,03. Vì vậy phải dùng `NULLIF(review_score, '')`.
- `net_revenue = quantity × unit_price × (1 − discount_rate) + shipping_fee` đúng hoàn toàn trên dữ liệu sạch, nên hồi quy theo đủ các thành phần này cho R² ≈ 1 (M0) mà không có ý nghĩa. Mô hình chính M3 **bỏ `unit_price` và `shipping_fee`**, thay bằng giá niêm yết `list_price` của danh mục sản phẩm.
- Tỷ lệ trả gần như đồng đều (7,73%), nên mô hình phân loại không tốt hơn đoán ngẫu nhiên (AUC test 0,493). Kết quả này được báo cáo đúng như vậy, không thổi phồng.
