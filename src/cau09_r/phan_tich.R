# =============================================================================
#  Cau 9 - R + SQLite: DBI/RSQLite, SQL co JOIN + GROUP BY, dplyr/tidyr,
#  ggplot2, hoi quy doanh thu, phan loai kha nang tra hang, ghi bang ket qua
#  tro lai CSDL va dong ket noi an toan.
#
#  /data chi doc -> copy project_data.sqlite sang output/project_data_results.sqlite
#  (file .sqlite bi gitignore) roi ghi vao ban copy.
#
#  Chay trong container rstudio:
#    Rscript /home/rstudio/src/cau09_r/phan_tich.R
#  Bien moi truong (tuy chon): DATA_DIR (mac dinh /data), IMG_DIR (mac dinh output/hinh)
# =============================================================================
suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(broom)
  library(grid)
})

lay_thu_muc_script <- function() {
  arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(arg) == 1) dirname(normalizePath(sub("^--file=", "", arg))) else getwd()
}
GOC <- lay_thu_muc_script()
DATA_DIR <- Sys.getenv("DATA_DIR", "/data")
OUT_DIR <- file.path(GOC, "output")
IMG_DIR <- Sys.getenv("IMG_DIR", file.path(OUT_DIR, "hinh"))
DB_GOC <- file.path(DATA_DIR, "project_data.sqlite")
DB_KQ <- file.path(OUT_DIR, "project_data_results.sqlite")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(IMG_DIR, showWarnings = FALSE, recursive = TRUE)
SEED <- 2026

# --- Giao dien bieu do (giong Cau 8) ------------------------------------------
chon_font <- function() {
  co <- unique(systemfonts::system_fonts()$family)
  for (f in c("TeX Gyre Heros", "DejaVu Sans", "Noto Sans", "Liberation Sans")) {
    if (f %in% co) return(f)
  }
  "sans"
}
FONT <- chon_font()
MAU <- list(nen = "#fcfcfb", chu = "#0b0b0b", chu2 = "#52514e", luoi = "#e4e3df",
            xanh = "#2a78d6", cam = "#eb6834", loai = c("#2a78d6", "#eb6834", "#1baf7a", "#eda100"))
nhan_so <- function(d = 1) scales::label_number(accuracy = 10^-d, big.mark = ".", decimal.mark = ",")
so_vn <- function(x, d = 0) formatC(x, format = "f", digits = d, big.mark = ".", decimal.mark = ",")
theme_btl <- function(co = 13) {
  theme_minimal(base_size = co, base_family = FONT) +
    theme(plot.background = element_rect(fill = MAU$nen, colour = NA),
          panel.background = element_rect(fill = MAU$nen, colour = NA),
          panel.grid.minor = element_blank(),
          panel.grid.major = element_line(colour = MAU$luoi, linewidth = 0.4),
          text = element_text(colour = MAU$chu), axis.text = element_text(colour = MAU$chu2),
          plot.title = element_text(face = "bold", size = co + 2),
          plot.subtitle = element_text(colour = MAU$chu2, size = co - 1),
          strip.text = element_text(hjust = 0, face = "bold", colour = MAU$chu),
          plot.title.position = "plot",
          legend.position = "top", legend.justification = "left")
}
mo_anh <- function(ten, rong = 1600, cao = 1000) {
  f <- file.path(IMG_DIR, ten)
  ragg::agg_png(f, width = rong, height = cao, res = 150, background = MAU$nen)
  cat("  anh:", f, "\n")
}
luu_anh <- function(p, ten, rong = 1600, cao = 1000) {
  mo_anh(ten, rong, cao)
  print(p)
  invisible(dev.off())
}
ghi_csv <- function(df, ten) write_csv(df, file.path(OUT_DIR, ten))

# AUC theo hang (Mann-Whitney): xac suat mot don bi tra co diem cao hon mot don khong tra
auc_hang <- function(diem, y) {
  r <- rank(diem)
  n1 <- sum(y == 1)
  n0 <- sum(y == 0)
  (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}
chi_so_phan_loai <- function(y, p, nguong, ten) {
  du_doan <- as.integer(p >= nguong)
  tp <- sum(du_doan == 1 & y == 1); fp <- sum(du_doan == 1 & y == 0)
  tn <- sum(du_doan == 0 & y == 0); fn <- sum(du_doan == 0 & y == 1)
  tibble(nguong_ten = ten, nguong = round(nguong, 4), tp = tp, fp = fp, tn = tn, fn = fn,
         accuracy = round((tp + tn) / length(y), 4),
         precision = round(ifelse(tp + fp == 0, NA_real_, tp / (tp + fp)), 4),
         recall = round(tp / (tp + fn), 4),
         specificity = round(tn / (tn + fp), 4),
         f1 = round(ifelse(tp == 0, 0, 2 * tp / (2 * tp + fp + fn)), 4))
}

# =============================================================================
main <- function() {
  # --- 1. Ket noi: copy CSDL goc roi mo ban copy; on.exit dam bao luon dong ---
  cat("== 1. Ket noi SQLite\n")
  stopifnot(file.copy(DB_GOC, DB_KQ, overwrite = TRUE))
  con <- dbConnect(RSQLite::SQLite(), DB_KQ)
  on.exit(dbDisconnect(con), add = TRUE)   # dong ket noi ca khi co loi giua chung
  cat("  bang:", paste(dbListTables(con), collapse = ", "), "\n")

  # --- 2. SQL co JOIN + GROUP BY --------------------------------------------
  cat("== 2. Truy van SQL\n")
  LOC <- "f.quality_flag NOT IN ('OUTLIER', 'DUPLICATE', 'LATE')"

  # 2a. Kiem tra o trong '': RSQLite doc cot INTEGER lan '' thanh 0 -> phai NULLIF
  kt_rong <- dbGetQuery(con, paste("
    SELECT SUM(review_score = '')              AS review_rong,
           SUM(campaign_id = '')               AS campaign_rong,
           SUM(review_score IS NULL)           AS review_is_null,
           ROUND(AVG(review_score), 4)         AS avg_review_sai,
           ROUND(AVG(NULLIF(review_score, '')), 4) AS avg_review_dung
    FROM fact_main f WHERE", LOC))
  print(kt_rong)
  ghi_csv(kt_rong, "kiem_tra_o_trong.csv")

  # 2b. Tong hop danh muc x phan khuc: JOIN 3 bang + GROUP BY
  sql_tong_hop <- paste("
    SELECT i.category, e.customer_segment,
           COUNT(*)                                 AS orders,
           COUNT(DISTINCT f.customer_id)            AS customers,
           ROUND(SUM(f.net_revenue), 2)             AS net_revenue,
           ROUND(AVG(f.net_revenue), 2)             AS avg_order_value,
           SUM(f.returned_flag)                     AS returned,
           ROUND(AVG(f.delivery_days), 2)           AS avg_delivery_days,
           ROUND(AVG(NULLIF(f.review_score, '')), 2) AS avg_review,
           ROUND(AVG(i.rating), 2)                  AS avg_product_rating
    FROM fact_main f
    JOIN item_master   i ON i.product_id  = f.product_id
    JOIN entity_master e ON e.customer_id = f.customer_id
    WHERE", LOC, "
    GROUP BY i.category, e.customer_segment
    ORDER BY i.category, e.customer_segment")
  tong_hop <- dbGetQuery(con, sql_tong_hop) %>%
    mutate(return_rate_pct = round(100 * returned / orders, 2))
  stopifnot(sum(tong_hop$orders) == 14408, sum(tong_hop$returned) == 1114,
            abs(sum(tong_hop$net_revenue) - 78218341.22) < 0.05)

  # 2c. Muc khach hang: GROUP BY customer + JOIN thuoc tinh khach
  khach <- dbGetQuery(con, paste("
    SELECT e.customer_id, e.customer_segment, e.age_group, e.gender, e.loyalty_score,
           e.preferred_channel, e.join_date,
           COUNT(f.order_id) AS orders, ROUND(SUM(f.net_revenue), 2) AS net_revenue,
           SUM(f.returned_flag) AS returned
    FROM entity_master e
    JOIN fact_main f ON f.customer_id = e.customer_id
    WHERE", LOC, "
    GROUP BY e.customer_id"))

  # 2d. Muc don hang (de mo hinh hoa): JOIN 3 bang, '' -> NULL ngay trong SQL
  don <- dbGetQuery(con, paste("
    SELECT f.order_id, f.timestamp, f.province, i.category, f.customer_segment,
           f.sales_channel, f.payment_method, f.quantity, f.unit_price, f.discount_rate,
           f.shipping_fee, f.net_revenue, f.delivery_days, f.returned_flag,
           NULLIF(f.review_score, '') AS review_score, NULLIF(f.campaign_id, '') AS campaign_id,
           i.brand, i.rating, i.list_price, e.age_group, e.gender, e.loyalty_score
    FROM fact_main f
    JOIN item_master   i ON i.product_id  = f.product_id
    JOIN entity_master e ON e.customer_id = f.customer_id
    WHERE", LOC))
  cat("  don sach:", nrow(don), " khach:", nrow(khach), "\n")
  stopifnot(nrow(don) == 14408)

  # --- 3. dplyr / tidyr ------------------------------------------------------
  cat("== 3. dplyr/tidyr\n")
  don <- don %>%
    mutate(across(where(is.character), ~ na_if(.x, "")),   # phong ho them
           review_score = as.numeric(review_score),
           delivery_days = as.numeric(delivery_days),
           has_campaign = as.integer(!is.na(campaign_id)),
           discount_10pp = discount_rate * 10,   # he so = tac dong khi giam gia tang 10 diem %
           has_review = as.integer(!is.na(review_score)),
           nhom_giao = cut(delivery_days, c(-Inf, 2, 5, Inf), labels = c("0–2 ngày", "3–5 ngày", "> 5 ngày")),
           muc_giam_gia = paste0(round(100 * discount_rate), "%"),
           across(c(category, customer_segment, sales_channel, payment_method, age_group), factor))
  stopifnot(sum(is.na(don$review_score)) == 5193)

  # pivot_wider: ma tran ty le tra (%) danh muc x phan khuc
  ma_tran_tra <- tong_hop %>%
    select(category, customer_segment, return_rate_pct) %>%
    pivot_wider(names_from = customer_segment, values_from = return_rate_pct)
  ma_tran_dt <- tong_hop %>%
    select(category, customer_segment, net_revenue) %>%
    pivot_wider(names_from = customer_segment, values_from = net_revenue)
  print(ma_tran_tra)

  # pivot_longer: dua nhieu yeu to ve dang dai de tinh ty le tra theo tung yeu to
  yeu_to <- don %>%
    transmute(returned_flag,
              `Danh mục` = as.character(category), `Phân khúc` = as.character(customer_segment),
              `Kênh bán` = as.character(sales_channel), `Thanh toán` = as.character(payment_method),
              `Thời gian giao` = as.character(nhom_giao), `Mức giảm giá` = muc_giam_gia,
              `Có đánh giá` = ifelse(has_review == 1, "Có", "Không")) %>%
    pivot_longer(-returned_flag, names_to = "yeu_to", values_to = "muc")
  tra_theo_yeu_to <- yeu_to %>%
    group_by(yeu_to, muc) %>%
    summarise(orders = n(), returned = sum(returned_flag), .groups = "drop") %>%
    mutate(rate = returned / orders,
           return_rate_pct = round(100 * rate, 2),
           ci_low_pct = round(100 * (rate - 1.96 * sqrt(rate * (1 - rate) / orders)), 2),
           ci_high_pct = round(100 * (rate + 1.96 * sqrt(rate * (1 - rate) / orders)), 2)) %>%
    select(-rate)
  # Kiem dinh chi binh phuong: ty le tra co khac nhau giua cac muc cua tung yeu to?
  # (them tinh giao hang va o danh muc x tinh de doi chieu dashboard Cau 8)
  kiem_dinh <- bind_rows(
    yeu_to,
    transmute(don, returned_flag, yeu_to = "Tỉnh giao hàng", muc = province),
    transmute(don, returned_flag, yeu_to = "Danh mục × tỉnh", muc = paste(category, province))) %>%
    group_by(yeu_to) %>%
    summarise(so_muc = n_distinct(muc),
              chi2 = unname(suppressWarnings(chisq.test(table(muc, returned_flag)))$statistic),
              p_value = suppressWarnings(chisq.test(table(muc, returned_flag)))$p.value,
              .groups = "drop") %>%
    mutate(chi2 = round(chi2, 3), p_value = round(p_value, 4)) %>%
    arrange(p_value)
  print(kiem_dinh)
  # ANOVA mot chieu: thoi gian giao co khac nhau giua cac tinh / danh muc khong?
  kiem_dinh_giao <- bind_rows(lapply(c("province", "category", "sales_channel"), function(v) {
    a <- anova(lm(reformulate(v, "delivery_days"), data = don))
    tibble(yeu_to = v, df = a$Df[1], f_value = round(a$`F value`[1], 3), p_value = round(a$`Pr(>F)`[1], 4))
  }))
  print(kiem_dinh_giao)

  # --- 4. Hoi quy doanh thu --------------------------------------------------
  cat("== 4. Hoi quy doanh thu\n")
  set.seed(SEED)
  # Chia 70/30 phan tang theo returned_flag (dung chung cho hoi quy va phan loai)
  don <- don %>% group_by(returned_flag) %>%
    mutate(tap = ifelse(runif(n()) < 0.7, "train", "test")) %>% ungroup()
  train <- filter(don, tap == "train")
  test <- filter(don, tap == "test")

  cong_thuc <- list(
    M0_cong_thuc = log(net_revenue) ~ log(quantity) + log(unit_price) + log(1 - discount_rate) + shipping_fee,
    M1_kinh_doanh = log(net_revenue) ~ category + customer_segment + sales_channel + payment_method +
      has_campaign + discount_rate,
    M2_them_so_luong = log(net_revenue) ~ category + customer_segment + sales_channel + payment_method +
      has_campaign + discount_10pp + log(quantity),
    M3_them_gia_niem_yet = log(net_revenue) ~ category + customer_segment + sales_channel + payment_method +
      has_campaign + discount_10pp + log(quantity) + log(list_price))
  r2_test <- function(m) {
    y <- log(test$net_revenue)
    du <- predict(m, newdata = test)
    c(r2 = 1 - sum((y - du)^2) / sum((y - mean(y))^2), rmse = sqrt(mean((y - du)^2)))
  }
  ds_mo_hinh <- lapply(cong_thuc, lm, data = train)
  so_sanh <- bind_rows(lapply(names(ds_mo_hinh), function(t) {
    g <- glance(ds_mo_hinh[[t]])
    kt <- r2_test(ds_mo_hinh[[t]])
    tibble(mo_hinh = t, n_train = nobs(ds_mo_hinh[[t]]), so_tham_so = length(coef(ds_mo_hinh[[t]])),
           r2_train = round(g$r.squared, 4), adj_r2_train = round(g$adj.r.squared, 4),
           r2_test = round(kt[["r2"]], 4), rmse_log_test = round(kt[["rmse"]], 4),
           aic = round(g$AIC, 1))
  }))
  # Mo hinh muc khach hang: tong doanh thu theo thuoc tinh khach
  khach <- khach %>%
    mutate(tenure_years = as.numeric(as.Date("2026-08-01") - as.Date(join_date)) / 365.25)
  m_khach <- lm(net_revenue ~ customer_segment + age_group + gender + loyalty_score +
                  preferred_channel + tenure_years, data = khach)
  gk <- glance(m_khach)
  so_sanh <- bind_rows(so_sanh, tibble(
    mo_hinh = "M4_muc_khach_hang", n_train = nobs(m_khach), so_tham_so = length(coef(m_khach)),
    r2_train = round(gk$r.squared, 4), adj_r2_train = round(gk$adj.r.squared, 4),
    r2_test = NA_real_, rmse_log_test = NA_real_, aic = round(gk$AIC, 1)))
  print(so_sanh)

  m3 <- ds_mo_hinh$M3_them_gia_niem_yet
  he_so <- tidy(m3, conf.int = TRUE) %>%
    mutate(across(c(estimate, std.error, statistic, conf.low, conf.high), ~ round(.x, 5)),
           p.value = signif(p.value, 4),
           # he so tren thang log -> % thay doi doanh thu; bien log(.) la he so co gian nen bo trong
           pct_effect = ifelse(term == "(Intercept)" | grepl("^log", term), NA_real_, round(100 * (exp(estimate) - 1), 2)))
  he_so_khach <- tidy(m_khach) %>% mutate(across(where(is.numeric), ~ signif(.x, 5)))
  print(he_so, n = 30)
  # ANOVA: dong gop cua tung nhom bien vao tong binh phuong (giai thich R2)
  anova_m3 <- tidy(anova(m3)) %>%
    mutate(pct_sumsq = round(100 * sumsq / sum(sumsq), 3),
           across(c(sumsq, meansq, statistic), ~ round(.x, 3)), p.value = signif(p.value, 4))
  print(anova_m3)
  phan_du <- augment(m3) %>% select(.fitted, .resid, .std.resid)
  kt_phan_du <- tibble(
    mean_resid = round(mean(phan_du$.resid), 6) + 0, sd_resid = round(sd(phan_du$.resid), 4),
    skewness = round(mean(((phan_du$.resid - mean(phan_du$.resid)) / sd(phan_du$.resid))^3), 4),
    pct_abs_std_resid_gt2 = round(100 * mean(abs(phan_du$.std.resid) > 2), 2))
  print(kt_phan_du)

  # --- 5. Phan loai kha nang tra hang (hoi quy logistic) ---------------------
  cat("== 5. Phan loai tra hang\n")
  ct_tra <- returned_flag ~ delivery_days + discount_rate + quantity + log(unit_price) + category +
    customer_segment + sales_channel + payment_method + has_campaign + has_review +
    loyalty_score + rating + age_group
  glm_tra <- glm(ct_tra, family = binomial(), data = train)
  p_train <- predict(glm_tra, newdata = train, type = "response")
  p_test <- predict(glm_tra, newdata = test, type = "response")
  # Nguong toi uu theo Youden J (= recall + specificity - 1) tren tap TRAIN, roi ap dung cho test
  ung_vien <- sort(unique(round(p_train, 4)))
  youden <- sapply(ung_vien, function(t) {
    d <- p_train >= t
    mean(d[train$returned_flag == 1]) + mean(!d[train$returned_flag == 0]) - 1
  })
  nguong_tot <- ung_vien[which.max(youden)]
  ty_le_tra_test <- mean(test$returned_flag)
  chi_so <- bind_rows(
    chi_so_phan_loai(test$returned_flag, rep(0, nrow(test)), 0.5, "Baseline: luôn đoán không trả"),
    chi_so_phan_loai(test$returned_flag, p_test, 0.5, "Logistic, ngưỡng 0,5"),
    chi_so_phan_loai(test$returned_flag, p_test, nguong_tot, "Logistic, ngưỡng Youden (train)")) %>%
    mutate(auc_test = round(c(0.5, rep(auc_hang(p_test, test$returned_flag), 2)), 4),
           auc_train = round(c(0.5, rep(auc_hang(p_train, train$returned_flag), 2)), 4),
           n_test = nrow(test), positive_rate_test_pct = round(100 * ty_le_tra_test, 2))
  print(chi_so)
  he_so_tra <- tidy(glm_tra) %>%
    mutate(odds_ratio = round(exp(estimate), 4), across(c(estimate, std.error, statistic), ~ round(.x, 5)),
           p.value = signif(p.value, 4))
  # Kiem dinh ty so hop ly: mo hinh co tot hon mo hinh chi co he so chan khong?
  glm_rong <- glm(returned_flag ~ 1, family = binomial(), data = train)
  lrt <- anova(glm_rong, glm_tra, test = "Chisq")
  lrt_bang <- tibble(df = lrt$Df[2], deviance = round(lrt$Deviance[2], 3), p_value = round(lrt$`Pr(>Chi)`[2], 4),
                     mcfadden_r2 = round(1 - glm_tra$deviance / glm_tra$null.deviance, 5))
  print(lrt_bang)
  # Ty le tra thuc te theo thap phan vi xac suat du doan (tap test)
  thap_phan_vi <- tibble(y = test$returned_flag, p = p_test) %>%
    mutate(decile = ntile(p, 10)) %>%
    group_by(decile) %>%
    summarise(orders = n(), p_min = round(min(p), 4), p_max = round(max(p), 4),
              mean_pred_pct = round(100 * mean(p), 2), actual_return_pct = round(100 * mean(y), 2),
              .groups = "drop")
  print(thap_phan_vi)
  du_doan <- test %>%
    transmute(order_id, returned_flag, prob_return = round(p_test, 5),
              pred_05 = as.integer(p_test >= 0.5), pred_youden = as.integer(p_test >= nguong_tot))
  # Duong ROC (tinh tay, khong dung pROC)
  nguong_roc <- c(Inf, sort(unique(p_test), decreasing = TRUE))
  roc <- tibble(nguong = nguong_roc,
                tpr = sapply(nguong_roc, function(t) mean(p_test[test$returned_flag == 1] >= t)),
                fpr = sapply(nguong_roc, function(t) mean(p_test[test$returned_flag == 0] >= t)))

  # --- 6. Ghi ket qua ra CSV va tro lai CSDL ---------------------------------
  cat("== 6. Ghi ket qua\n")
  ket_qua <- list(
    kq_tong_hop_danh_muc_phan_khuc = tong_hop,
    kq_ma_tran_ty_le_tra = ma_tran_tra,
    kq_ma_tran_doanh_thu = ma_tran_dt,
    kq_tra_theo_yeu_to = tra_theo_yeu_to,
    kq_kiem_dinh_chi2 = kiem_dinh,
    kq_kiem_dinh_giao_hang = kiem_dinh_giao,
    kq_hoi_quy_so_sanh = so_sanh,
    kq_hoi_quy_he_so = he_so,
    kq_hoi_quy_anova = anova_m3,
    kq_hoi_quy_phan_du = kt_phan_du,
    kq_hoi_quy_khach_he_so = he_so_khach,
    kq_phan_loai_chi_so = chi_so,
    kq_phan_loai_he_so = he_so_tra,
    kq_phan_loai_lrt = lrt_bang,
    kq_phan_loai_thap_phan_vi = thap_phan_vi,
    kq_phan_loai_du_doan = du_doan)
  for (ten in names(ket_qua)) {
    dbWriteTable(con, ten, as.data.frame(ket_qua[[ten]]), overwrite = TRUE)
    if (ten != "kq_phan_loai_du_doan") ghi_csv(ket_qua[[ten]], paste0(sub("^kq_", "", ten), ".csv"))
  }
  # Doc lai tu CSDL de xac nhan da ghi (so dong lay tu SQLite, khong lay tu R)
  da_ghi <- bind_rows(lapply(names(ket_qua), function(ten) {
    tibble(bang = ten, so_dong = dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM \"", ten, "\""))$n,
           so_cot = length(dbListFields(con, ten)))
  }))
  stopifnot(all(da_ghi$so_dong == sapply(ket_qua, nrow)))
  ghi_csv(da_ghi, "bang_ghi_lai_csdl.csv")
  writeLines(c(paste("CSDL ket qua:", "output/project_data_results.sqlite"),
               paste("Tat ca bang trong CSDL:", paste(dbListTables(con), collapse = ", ")),
               "", "Bang ket qua da ghi (bang | so dong | so cot):",
               sprintf("  %-34s %6d %3d", da_ghi$bang, da_ghi$so_dong, da_ghi$so_cot)),
             file.path(OUT_DIR, "bang_ghi_lai_csdl.txt"))
  print(da_ghi)

  # --- 7. ggplot2 ----------------------------------------------------------
  cat("== 7. Bieu do\n")
  bieu_do(tong_hop, tra_theo_yeu_to, he_so, phan_du, roc, chi_so)

  invisible(con)   # tra ve de kiem tra sau khi main() ket thuc
}

# =============================================================================
bieu_do <- function(tong_hop, tra_theo_yeu_to, he_so, phan_du, roc, chi_so) {
  # (a) Doanh thu theo danh muc x phan khuc (ket qua truy van JOIN + GROUP BY)
  p1 <- ggplot(tong_hop, aes(x = net_revenue / 1e6, y = reorder(category, net_revenue, sum),
                             fill = customer_segment)) +
    geom_col(position = position_dodge2(reverse = TRUE, padding = 0.1), width = 0.8) +
    scale_fill_manual(values = MAU$loai, name = "Phân khúc") +
    scale_x_continuous(labels = nhan_so(1), expand = expansion(mult = c(0, 0.05))) +
    labs(title = "Doanh thu ròng theo danh mục và phân khúc khách hàng",
         subtitle = "Kết quả truy vấn SQL JOIN fact_main – item_master – entity_master, GROUP BY 2 chiều",
         x = "Triệu đơn vị tiền tệ", y = NULL) +
    theme_btl() + theme(panel.grid.major.y = element_blank())
  luu_anh(p1, "cau09-doanh-thu-danh-muc-phan-khuc.png")

  # (b) Ty le tra theo tung yeu to, kem khoang tin cay 95%
  tb <- 100 * 1114 / 14408
  # Thu tu muc: giam gia va thoi gian giao theo gia tri, con lai theo ABC (muc dau o tren cung)
  thu_tu <- c("0%", "5%", "10%", "15%", "20%", "30%", "0–2 ngày", "3–5 ngày", "> 5 ngày")
  thu_tu <- c(sort(setdiff(unique(tra_theo_yeu_to$muc), thu_tu)), thu_tu)
  tra_theo_yeu_to <- mutate(tra_theo_yeu_to, muc = factor(muc, levels = rev(thu_tu)))
  p2 <- ggplot(tra_theo_yeu_to, aes(x = return_rate_pct, y = muc)) +
    geom_vline(xintercept = tb, linetype = "dashed", colour = MAU$chu2) +
    geom_errorbarh(aes(xmin = ci_low_pct, xmax = ci_high_pct), height = 0.3, colour = MAU$xanh) +
    geom_point(colour = MAU$xanh, size = 2.4) +
    facet_wrap(~yeu_to, scales = "free_y", ncol = 4) +
    scale_x_continuous(labels = nhan_so(0)) +
    labs(title = "Tỷ lệ hoàn trả theo từng yếu tố (điểm) và khoảng tin cậy 95%",
         subtitle = paste0("Nét đứt: trung bình chung ", so_vn(tb, 2),
                           "%. Các khoảng tin cậy chồng lên nhau → tín hiệu yếu"),
         x = "% đơn bị trả", y = NULL) +
    theme_btl(12)
  luu_anh(p2, "cau09-tra-hang-theo-yeu-to.png", cao = 1100)

  # (c) He so hoi quy M3 (% thay doi doanh thu, khoang tin cay 95%)
  hs <- he_so %>% filter(term != "(Intercept)", !grepl("^log", term)) %>%
    mutate(low = 100 * (exp(conf.low) - 1), high = 100 * (exp(conf.high) - 1),
           y_nghia = ifelse(p.value < 0.05, "p < 0,05", "p ≥ 0,05"),
           term = sub("^category", "Danh mục: ", term),
           term = sub("^customer_segment", "Phân khúc: ", term),
           term = sub("^sales_channel", "Kênh: ", term),
           term = sub("^payment_method", "Thanh toán: ", term),
           term = sub("^has_campaign$", "Có mã chiến dịch", term),
           term = sub("^discount_10pp$", "Giảm giá tăng 10 điểm %", term),
           term = reorder(term, pct_effect))
  p3 <- ggplot(hs, aes(x = pct_effect, y = term, colour = y_nghia)) +
    geom_vline(xintercept = 0, colour = MAU$chu2) +
    geom_errorbarh(aes(xmin = low, xmax = high), height = 0.3) +
    geom_point(size = 2.4) +
    scale_colour_manual(values = c("p < 0,05" = MAU$xanh, "p ≥ 0,05" = "#a3a29c"), name = NULL) +
    scale_x_continuous(labels = nhan_so(0)) +
    labs(title = "Hồi quy log(doanh thu đơn) – mô hình M3: tác động của từng biến",
         subtitle = paste("% thay đổi doanh thu so với nhóm tham chiếu (Beauty, Loyal, marketplace, bank_transfer), giữ các biến khác cố định.",
                          "Hệ số co giãn của log(số lượng), log(giá niêm yết) xem bảng", sep = "\n"),
         x = "% thay đổi doanh thu", y = NULL) +
    theme_btl(12)
  luu_anh(p3, "cau09-hoi-quy-he-so.png", cao = 1100)

  # (d) Kiem tra phan du: phan du theo gia tri du bao + Q-Q plot, ghep bang grid
  set.seed(SEED)
  mau_pd <- slice_sample(phan_du, n = min(4000, nrow(phan_du)))
  p4a <- ggplot(mau_pd, aes(.fitted, .resid)) +
    geom_point(alpha = 0.25, size = 0.9, colour = MAU$xanh) +
    geom_hline(yintercept = 0, colour = MAU$cam) +
    geom_smooth(method = "loess", formula = y ~ x, se = FALSE, colour = MAU$chu, linewidth = 0.7) +
    scale_x_continuous(labels = nhan_so(1)) + scale_y_continuous(labels = nhan_so(1)) +
    labs(title = "Phần dư theo giá trị dự báo", subtitle = "Mẫu 4.000 điểm của tập train",
         x = "Giá trị dự báo log(doanh thu)", y = "Phần dư") + theme_btl(12)
  p4b <- ggplot(mau_pd, aes(sample = .std.resid)) +
    stat_qq(alpha = 0.3, size = 0.9, colour = MAU$xanh) + stat_qq_line(colour = MAU$cam) +
    scale_x_continuous(labels = nhan_so(0)) + scale_y_continuous(labels = nhan_so(0)) +
    labs(title = "Biểu đồ Q-Q phần dư chuẩn hóa", subtitle = "Lệch khỏi đường thẳng ở hai đuôi",
         x = "Phân vị lý thuyết", y = "Phân vị mẫu") + theme_btl(12)
  mo_anh("cau09-hoi-quy-phan-du.png", cao = 800)
  grid.newpage()
  pushViewport(viewport(layout = grid.layout(1, 2)))
  print(p4a, vp = viewport(layout.pos.row = 1, layout.pos.col = 1))
  print(p4b, vp = viewport(layout.pos.row = 1, layout.pos.col = 2))
  invisible(dev.off())

  # (e) Duong ROC tren tap test
  auc <- chi_so$auc_test[2]
  diem <- chi_so %>% filter(grepl("Logistic", nguong_ten)) %>%
    transmute(nhan = paste0(nguong_ten, ": recall ", so_vn(100 * recall, 1), "%, FPR ",
                            so_vn(100 * (1 - specificity), 1), "%"),
              fpr = 1 - specificity, tpr = recall)
  p5 <- ggplot(roc, aes(fpr, tpr)) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = MAU$chu2) +
    geom_step(colour = MAU$xanh, linewidth = 0.9, direction = "vh") +
    geom_point(data = diem, aes(colour = nhan), size = 3.5) +
    scale_colour_manual(values = c(MAU$cam, MAU$chu), name = NULL) +
    guides(colour = guide_legend(ncol = 1)) +
    scale_x_continuous(breaks = seq(0, 1, 0.2), labels = nhan_so(1)) +
    scale_y_continuous(breaks = seq(0, 1, 0.2), labels = nhan_so(1)) +
    coord_equal() +
    labs(title = "Đường ROC – hồi quy logistic dự báo trả hàng (tập test)",
         subtitle = paste0("AUC = ", so_vn(auc, 3), "; nét đứt: đoán ngẫu nhiên (AUC = 0,5)"),
         x = "Tỷ lệ dương tính giả (FPR)", y = "Tỷ lệ phát hiện (recall)") +
    theme_btl(12)
  luu_anh(p5, "cau09-roc.png", rong = 1300, cao = 1300)
}

con <- main()
# Sau khi main() ket thuc, on.exit da dong ket noi:
stopifnot(!DBI::dbIsValid(con))
cat("Ket noi SQLite da dong (dbIsValid = FALSE). Font bieu do:", FONT, "\n")

# Anh minh chung: mo lai CSDL ket qua o che do chi doc, liet ke bang kq_* va so dong
minh_chung <- function() {
  c2 <- dbConnect(RSQLite::SQLite(), DB_KQ, flags = RSQLite::SQLITE_RO)
  on.exit(dbDisconnect(c2), add = TRUE)
  bang <- dbGetQuery(c2, "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name")$name
  dem <- vapply(bang, function(t) dbGetQuery(c2, paste0('SELECT COUNT(*) AS n FROM "', t, '"'))$n, numeric(1))
  dong <- c("$ Rscript /home/rstudio/src/cau09_r/phan_tich.R   (trich ket qua)",
            "",
            "> dbListTables(c2)    # c2: mo lai output/project_data_results.sqlite (chi doc)",
            sprintf("  %-34s %6d dong%s", bang, as.integer(dem), ifelse(grepl("^kq_", bang), "   <- ghi boi R", "")),
            "",
            "> dbIsValid(con)      # sau khi main() ket thuc, on.exit(dbDisconnect(con)) da chay",
            paste0("[1] ", DBI::dbIsValid(con)))
  mono <- intersect(c("Nimbus Mono PS", "TeX Gyre Cursor", "DejaVu Sans Mono", "mono"),
                    c(unique(systemfonts::system_fonts()$family), "mono"))[1]
  mo_anh("cau09-minh-chung-csdl.png", rong = 1600, cao = 120 + 34 * length(dong))
  grid.newpage()
  grid.rect(gp = gpar(fill = "#1a1a19", col = NA))
  grid.text(dong, x = unit(30, "pt"), y = unit(1, "npc") - unit(30 + 17 * seq_along(dong), "pt"),
            hjust = 0, gp = gpar(fontfamily = mono, fontsize = 12, col = "#f0efec"))
  invisible(dev.off())
}
minh_chung()
