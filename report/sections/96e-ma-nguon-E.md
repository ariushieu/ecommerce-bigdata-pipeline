### Mã nguồn Câu 8, 9 – Phạm Văn Quyết

Mã đầy đủ nằm ở `src/cau08_bigsheets/dashboard.R` và `src/cau09_r/phan_tich.R`. Dưới đây là các đoạn quan trọng nhất, đã rút gọn.

**1. Câu 8 – các bước BigSheets B3–B6 viết bằng dplyr** (`dashboard.R`)

```r
sach <- orders %>% filter(!quality_flag %in% c("OUTLIER", "DUPLICATE", "LATE"))   # B3: 14.408 dong
sach <- sach %>%
  mutate(order_month = substr(timestamp, 1, 7),              # B4: =LEFT(#timestamp, 7)
         is_late = as.integer(delivery_days > 5),            #     =IF(#delivery_days > 5, 1, 0)
         has_campaign = as.integer(!is.na(campaign_id)))     #     =IF(ISNULL(#campaign_id), 0, 1)
day_du <- sach %>%                                            # B5: Join 2 collection danh muc
  left_join(products %>% select(product_id, brand, rating), by = "product_id") %>%
  left_join(customers %>% select(customer_id, age_group, home_province = province), by = "customer_id")
cat_prov <- day_du %>% group_by(category, province) %>%      # B6: Pivot danh muc x tinh
  summarise(orders = n(), net_revenue = round(sum(net_revenue), 2), returned = sum(returned_flag),
            return_rate_pct = round(100 * returned / orders, 2),
            avg_delivery_days = round(mean(delivery_days), 2), late_orders = sum(is_late), .groups = "drop")
```

**2. Câu 9 – kết nối an toàn tới bản copy CSDL**

```r
main <- function() {
  stopifnot(file.copy(DB_GOC, DB_KQ, overwrite = TRUE))   # /data chi doc -> ghi vao ban copy
  con <- dbConnect(RSQLite::SQLite(), DB_KQ)
  on.exit(dbDisconnect(con), add = TRUE)                  # luon dong, ke ca khi loi giua chung
  ...
  invisible(con)
}
con <- main()
stopifnot(!DBI::dbIsValid(con))                           # xac nhan ket noi da dong
```

**3. SQL có JOIN 3 bảng và GROUP BY; ô trống `''` đổi thành NULL bằng `NULLIF`**

```sql
SELECT i.category, e.customer_segment,
       COUNT(*) AS orders, COUNT(DISTINCT f.customer_id) AS customers,
       ROUND(SUM(f.net_revenue), 2) AS net_revenue, SUM(f.returned_flag) AS returned,
       ROUND(AVG(f.delivery_days), 2) AS avg_delivery_days,
       ROUND(AVG(NULLIF(f.review_score, '')), 2) AS avg_review
FROM fact_main f
JOIN item_master   i ON i.product_id  = f.product_id
JOIN entity_master e ON e.customer_id = f.customer_id
WHERE f.quality_flag NOT IN ('OUTLIER', 'DUPLICATE', 'LATE')
GROUP BY i.category, e.customer_segment
```

Không có `NULLIF`, cả SQLite (`AVG`) lẫn RSQLite (khi đọc cột INTEGER lẫn chuỗi) đều coi `''` là 0. Kết quả là điểm đánh giá trung bình bị tính sai thành 1,94 thay vì 3,03 (`kiem_tra_o_trong.csv`).

**4. tidyr: dạng rộng và dạng dài**

```r
ma_tran_tra <- tong_hop %>% select(category, customer_segment, return_rate_pct) %>%
  pivot_wider(names_from = customer_segment, values_from = return_rate_pct)      # 6 x 4
yeu_to <- don %>% transmute(returned_flag, `Danh mục` = as.character(category), `Kênh bán` = ...) %>%
  pivot_longer(-returned_flag, names_to = "yeu_to", values_to = "muc")            # 7 yeu to -> dang dai
```

**5. Hồi quy doanh thu (M3) và phân loại trả hàng**

```r
m3 <- lm(log(net_revenue) ~ category + customer_segment + sales_channel + payment_method +
           has_campaign + discount_10pp + log(quantity) + log(list_price), data = train)
he_so <- broom::tidy(m3, conf.int = TRUE)            # bang he so -> CSV + CSDL
glm_tra <- glm(returned_flag ~ delivery_days + discount_rate + quantity + log(unit_price) + category +
                 customer_segment + sales_channel + payment_method + has_campaign + has_review +
                 loyalty_score + rating + age_group, family = binomial(), data = train)

# AUC theo hang (Mann-Whitney), khong can pROC
auc_hang <- function(diem, y) {
  r <- rank(diem); n1 <- sum(y == 1); n0 <- sum(y == 0)
  (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}
```

**6. Ghi kết quả trở lại CSDL rồi đọc lại để xác nhận**

```r
for (ten in names(ket_qua)) dbWriteTable(con, ten, as.data.frame(ket_qua[[ten]]), overwrite = TRUE)
da_ghi <- bind_rows(lapply(names(ket_qua), function(ten) tibble(
  bang = ten, so_dong = dbGetQuery(con, paste0('SELECT COUNT(*) AS n FROM "', ten, '"'))$n)))
stopifnot(all(da_ghi$so_dong == sapply(ket_qua, nrow)))
```

*[Bảng:c09-bang-ghi-lai]. Các bảng kết quả đã ghi vào `output/project_data_results.sqlite` (`bang_ghi_lai_csdl.txt`)*

| Bảng | Số dòng | Nội dung |
|---|---:|---|
| `kq_tong_hop_danh_muc_phan_khuc` | 24 | Kết quả SQL JOIN + GROUP BY |
| `kq_ma_tran_ty_le_tra`, `kq_ma_tran_doanh_thu` | 6 + 6 | Ma trận `pivot_wider` |
| `kq_tra_theo_yeu_to` | 28 | Tỷ lệ trả theo 7 yếu tố, kèm khoảng tin cậy 95% |
| `kq_kiem_dinh_chi2`, `kq_kiem_dinh_giao_hang` | 9 + 3 | Kiểm định χ², ANOVA thời gian giao |
| `kq_hoi_quy_so_sanh`, `kq_hoi_quy_he_so`, `kq_hoi_quy_anova`, `kq_hoi_quy_phan_du`, `kq_hoi_quy_khach_he_so` | 5 + 18 + 9 + 1 + 13 | Hồi quy doanh thu |
| `kq_phan_loai_chi_so`, `kq_phan_loai_he_so`, `kq_phan_loai_lrt`, `kq_phan_loai_thap_phan_vi` | 3 + 26 + 1 + 10 | Phân loại trả hàng |
| `kq_phan_loai_du_doan` | 4.288 | Xác suất trả và nhãn dự báo cho từng đơn của tập test |

**Nhận xét [Bảng:c09-bang-ghi-lai]:** 16 bảng `kq_*` nằm cạnh 3 bảng gốc không bị sửa (`fact_main` vẫn 15.000 dòng, `test.sh` kiểm tra). Các bảng nhỏ còn được ghi ra CSV trong `src/cau09_r/output/`; tệp `.sqlite` không commit, chạy lại script sẽ tạo lại.

**7. Chi tiết mô hình của mục 4.2.4–4.2.5**

*[Bảng:c09-hoi-quy-he-so]. Hệ số chính của M3 (`hoi_quy_he_so.csv`; nhóm tham chiếu: Beauty, Loyal, marketplace, bank_transfer)*

| Biến | Hệ số | p-value | Diễn giải |
|---|---:|---:|---|
| `log(quantity)` | 0,992 | < 0,001 | Số lượng +1% → doanh thu +0,99% |
| `log(list_price)` | 0,427 | < 0,001 | Giá niêm yết +1% → doanh thu +0,43% |
| Giảm giá tăng 10 điểm % | −0,119 | < 0,001 | −11,25% |
| Danh mục Sports | 0,093 | < 0,001 | +9,73% so với Beauty |
| Danh mục Electronics | 0,056 | < 0,001 | +5,75% |
| Danh mục Fashion | −0,070 | < 0,001 | −6,79% |
| Danh mục Home | −0,026 | 0,026 | −2,56% |
| Phân khúc VIP | 0,023 | 0,016 | +2,33% so với Loyal |
| Kênh bán, thanh toán, có chiến dịch | | > 0,16 | Không có ý nghĩa |

**Nhận xét [Bảng:c09-hoi-quy-he-so]:** Mức −11,25% cho mỗi 10 điểm giảm giá gần đúng cơ chế của công thức doanh thu, tức chi phí trực tiếp của giảm giá; dữ liệu không có nhóm đối chứng nên chưa kết luận được giảm giá có làm tăng số đơn. Phần dư chiếm 17,7% tổng bình phương của M3 (`hoi_quy_anova.csv`).

![](../../docs/images/cau09-hoi-quy-phan-du.png){width=70%}

*[Hình:c09-hoi-quy-phan-du]. Kiểm tra phần dư của M3: phần dư theo giá trị dự báo và biểu đồ Q-Q*

**Nhận xét [Hình:c09-hoi-quy-phan-du]:** Phần dư gần đối xứng (độ xiên 0,07) nhưng đuôi dày hơn chuẩn: 7,07% phần dư chuẩn hóa vượt ±2, so với khoảng 5% của phân phối chuẩn. Đường loess cong lên ở vùng dự báo thấp vì phí vận chuyển (0–50) là khoản cộng thêm cố định.

**Mô hình logistic:** 13 biến (ngày giao, giảm giá, số lượng, `log(unit_price)`, danh mục, phân khúc, kênh bán, thanh toán, có chiến dịch, có đánh giá, điểm thân thiết, rating sản phẩm, nhóm tuổi; 25 hệ số); ngưỡng Youden tối đa hóa recall + specificity − 1 trên tập train. Ở ngưỡng 0,0758, mô hình gắn cờ 2.415/4.288 đơn (56%). Tỷ lệ trả thực tế theo 10 nhóm xác suất dự báo dao động 5,84–9,81% mà không tăng dần (`phan_loai_thap_phan_vi.csv`); chỉ hệ số kênh mobile và web (odds ratio 1,26 và 1,24) có ý nghĩa ở mức 5%, đúng cỡ số hệ số "có ý nghĩa" do ngẫu nhiên khi có 25 hệ số.

**8. Số liệu chi tiết của mục 1.4.4, 4.2.2 và 4.2.3**

*[Bảng:c09-phien-ban-r]. Phiên bản các gói R sử dụng (R 4.4, tidyverse)*

| Thành phần | Phiên bản |
|---|---|
| R | 4.4.3 |
| DBI / RSQLite (SQLite nhúng) | 1.2.3 / 2.3.9 (3.47.1) |
| dplyr / tidyr / readr | 1.1.4 / 1.3.1 / 2.1.5 |
| ggplot2 / ragg / scales | 3.5.2 / 1.3.3 / 1.3.0 |
| broom | 1.0.8 |

**Nhận xét [Bảng:c09-phien-ban-r]:** Mọi gói được cài sẵn trong môi trường R của nhóm (cấu hình trong thư mục `infra/`) nên kết quả tái lập được. Môi trường không có `patchwork` hay `pROC`, nên dashboard được ghép bằng `grid` và AUC được tính tay theo hạng.

*[Bảng:c06-roi-bo-phan-khuc]. Mức nguy cơ rời bỏ theo phân khúc khách hàng (`churn_summary.csv`)*

| Phân khúc | Khách | HIGH | MEDIUM | LOW | HIGH (%) | Recency TB (ngày) |
|---|---:|---:|---:|---:|---:|---:|
| Loyal | 296 | 28 | 51 | 217 | 9,46 | 44,66 |
| New | 303 | 41 | 48 | 214 | 13,53 | 51,10 |
| Regular | 302 | 37 | 61 | 204 | 12,25 | 50,00 |
| VIP | 299 | 41 | 62 | 196 | 13,71 | 49,35 |
| **Tất cả** | **1.200** | **147** | **222** | **831** | **12,25** | **48,80** |

**Nhận xét [Bảng:c06-roi-bo-phan-khuc]:** Danh sách 369 khách HIGH và MEDIUM nằm trong `churn_risk_customers.csv`. So với nhóm LOW, khách HIGH mua 9,82 so với 12,31 đơn/khách, trả 7,48% so với 7,86%, giao 3,05 so với 3,03 ngày (`churn_by_risk.csv`).

*[Bảng:c09-kiem-dinh]. Kiểm định sự khác biệt về tỷ lệ trả (χ²) và thời gian giao (ANOVA một chiều)*

| Chỉ số | Yếu tố | Số mức | Thống kê | p-value |
|---|---|---:|---:|---:|
| Tỷ lệ trả | Kênh bán | 3 | χ² = 4,110 | 0,1281 |
| Tỷ lệ trả | Có/không đánh giá | 2 | χ² = 0,951 | 0,3294 |
| Tỷ lệ trả | Ô danh mục × tỉnh | 108 | χ² = 105,269 | 0,5292 |
| Tỷ lệ trả | Thanh toán | 4 | χ² = 2,102 | 0,5516 |
| Tỷ lệ trả | Tỉnh giao hàng | 18 | χ² = 15,589 | 0,5532 |
| Tỷ lệ trả | Phân khúc | 4 | χ² = 1,196 | 0,7540 |
| Tỷ lệ trả | Danh mục | 6 | χ² = 2,071 | 0,8392 |
| Tỷ lệ trả | Thời gian giao (0–2 / 3–5 / > 5 ngày) | 3 | χ² = 0,089 | 0,9567 |
| Tỷ lệ trả | Mức giảm giá | 6 | χ² = 0,942 | 0,9671 |
| Ngày giao | Tỉnh giao hàng | 18 | F = 0,869 | 0,6114 |
| Ngày giao | Danh mục | 6 | F = 2,597 | 0,0236 |
| Ngày giao | Kênh bán | 3 | F = 2,776 | 0,0623 |

**Nhận xét [Bảng:c09-kiem-dinh]:** Không p-value nào của tỷ lệ trả nhỏ hơn 0,05; chỉ thời gian giao theo danh mục có ý nghĩa (diễn giải ở mục 4.2.3).
