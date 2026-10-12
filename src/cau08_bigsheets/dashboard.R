# =============================================================================
#  Cau 8 - Tinh lai bang R/dplyr tung buoc cua quy trinh BigSheets (mo phong)
#  va ve dashboard doanh thu - hoan tra - giao hang theo danh muc va tinh.
#
#  Moi buoc ung voi mot buoc giao dien BigSheets trong huong-dan-bigsheets.md
#  (B1..B9). So dong sau moi buoc ghi vao output/buoc_bigsheets.csv de nguoi
#  khong lap trinh doi chieu voi so dong BigSheets hien thi.
#
#  Chay trong container rstudio:
#    Rscript /home/rstudio/src/cau08_bigsheets/dashboard.R
#  Bien moi truong (tuy chon): DATA_DIR (mac dinh /data), IMG_DIR (mac dinh output/hinh)
# =============================================================================
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(grid)
})

# --- Duong dan --------------------------------------------------------------
lay_thu_muc_script <- function() {
  arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(arg) == 1) dirname(normalizePath(sub("^--file=", "", arg))) else getwd()
}
GOC <- lay_thu_muc_script()
DATA_DIR <- Sys.getenv("DATA_DIR", "/data")
OUT_DIR <- file.path(GOC, "output")
IMG_DIR <- Sys.getenv("IMG_DIR", file.path(OUT_DIR, "hinh"))
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(IMG_DIR, showWarnings = FALSE, recursive = TRUE)

# --- Giao dien bieu do chung (font co dau tieng Viet) ------------------------
chon_font <- function() {
  # TeX Gyre Heros co du dau tieng Viet trong anh rocker; neu khong co thi lui ve sans
  co <- unique(systemfonts::system_fonts()$family)
  for (f in c("TeX Gyre Heros", "DejaVu Sans", "Noto Sans", "Liberation Sans")) {
    if (f %in% co) return(f)
  }
  "sans"
}
FONT <- chon_font()
MAU <- list(nen = "#fcfcfb", chu = "#0b0b0b", chu2 = "#52514e", luoi = "#e4e3df",
            xanh = "#2a78d6", cam = "#eb6834",
            day = c("#eef5fd", "#b7d3f6", "#6da7ec", "#256abf", "#0d366b"))
nhan_so <- function(d = 1) scales::label_number(accuracy = 10^-d, big.mark = ".", decimal.mark = ",")
so_vn <- function(x, d = 0) {
  formatC(x, format = "f", digits = d, big.mark = ".", decimal.mark = ",")
}
theme_btl <- function(co = 13) {
  theme_minimal(base_size = co, base_family = FONT) +
    theme(plot.background = element_rect(fill = MAU$nen, colour = NA),
          panel.background = element_rect(fill = MAU$nen, colour = NA),
          panel.grid.major.y = element_blank(), panel.grid.minor = element_blank(),
          panel.grid.major.x = element_line(colour = MAU$luoi, linewidth = 0.4),
          text = element_text(colour = MAU$chu),
          axis.text = element_text(colour = MAU$chu2),
          plot.title = element_text(face = "bold", size = co + 2),
          plot.subtitle = element_text(colour = MAU$chu2, size = co - 1),
          plot.caption = element_text(colour = MAU$chu2, size = co - 3, hjust = 0),
          plot.title.position = "plot", plot.caption.position = "plot",
          plot.margin = margin(6, 18, 6, 6),
          legend.position = "top", legend.justification = "left")
}
luu_anh <- function(p, ten, rong = 1600, cao = 1000) {
  f <- file.path(IMG_DIR, ten)
  ragg::agg_png(f, width = rong, height = cao, res = 150, background = MAU$nen)
  print(p)
  invisible(dev.off())
  cat("  anh:", f, "\n")
}

buoc <- tibble(buoc = character(), mo_ta = character(), so_dong = integer())
ghi_buoc <- function(ma, mo_ta, df) {
  buoc <<- add_row(buoc, buoc = ma, mo_ta = mo_ta, so_dong = nrow(df))
  cat(sprintf("  %-4s %-60s %6d dong\n", ma, mo_ta, nrow(df)))
}

# =============================================================================
# B1. Collection (master workbook) tu 3 tep CSV. readr tu bo BOM o dong tieu de,
#     giong tuy chon "Headers included" cua bo doc CSV trong BigSheets.
# =============================================================================
cat("== B1-B2: doc collection\n")
doc_csv <- function(tep) {
  read_csv(file.path(DATA_DIR, tep), col_types = cols(.default = col_character()),
           na = character(), progress = FALSE)
}
orders_raw <- doc_csv("orders.csv")
customers <- doc_csv("customers.csv")
products <- doc_csv("products.csv")
stopifnot(names(orders_raw)[1] == "record_id")   # BOM da duoc bo
ghi_buoc("B1", "Collection orders (doc orders.csv, co tieu de)", orders_raw)
ghi_buoc("B1", "Collection customers", customers)
ghi_buoc("B1", "Collection products", products)

# B2. Dat kieu cot (BigSheets: Edit column -> chon kieu); o trong -> NA
orders <- orders_raw %>%
  mutate(across(c(quantity, returned_flag), as.integer),
         across(c(unit_price, discount_rate, shipping_fee, net_revenue, delivery_days), as.numeric),
         review_score = suppressWarnings(as.integer(na_if(review_score, ""))),
         campaign_id = na_if(campaign_id, ""))

# =============================================================================
# B3. Loc chat luong (sheet Filter): giu OK va MISSING
# =============================================================================
cat("== B3: loc quality_flag\n")
sach <- orders %>% filter(!quality_flag %in% c("OUTLIER", "DUPLICATE", "LATE"))
ghi_buoc("B3", "Filter: bo quality_flag OUTLIER/DUPLICATE/LATE", sach)
stopifnot(nrow(sach) == 14408)

# =============================================================================
# B4. Calculated columns
# =============================================================================
cat("== B4: cot tinh toan\n")
sach <- sach %>%
  mutate(order_month = substr(timestamp, 1, 7),                     # =LEFT(#timestamp, 7)
         is_late = as.integer(delivery_days > 5),                   # =IF(#delivery_days > 5, 1, 0)
         has_campaign = as.integer(!is.na(campaign_id)),            # =IF(ISNULL(#campaign_id), 0, 1)
         revenue_bucket = case_when(net_revenue < 2000 ~ "1. < 2.000",
                                    net_revenue < 5000 ~ "2. 2.000-5.000",
                                    net_revenue < 10000 ~ "3. 5.000-10.000",
                                    TRUE ~ "4. >= 10.000"))
ghi_buoc("B4", "Them order_month, is_late, has_campaign, revenue_bucket", sach)

# =============================================================================
# B5. Join voi 2 collection danh muc (sheet Join, kieu Left)
# =============================================================================
cat("== B5: join danh muc\n")
day_du <- sach %>%
  left_join(products %>% select(product_id, brand, rating), by = "product_id") %>%
  left_join(customers %>% select(customer_id, age_group, home_province = province),
            by = "customer_id")
ghi_buoc("B5", "Join products (brand) + customers (age_group, home_province)", day_du)
stopifnot(nrow(day_du) == 14408, !anyNA(day_du$brand), !anyNA(day_du$age_group))

# =============================================================================
# B6. Pivot/Group: danh muc x tinh giao hang (bang chinh cua dashboard)
# =============================================================================
cat("== B6: group by\n")
tong_hop <- function(df) {
  summarise(df, orders = n(), net_revenue = round(sum(net_revenue), 2),
            returned = sum(returned_flag),
            return_rate_pct = round(100 * returned / orders, 2),
            avg_delivery_days = round(mean(delivery_days), 2),
            late_orders = sum(is_late),
            late_pct = round(100 * late_orders / orders, 2), .groups = "drop")
}
cat_prov <- day_du %>% group_by(category, province) %>% tong_hop() %>% arrange(category, province)
ghi_buoc("B6", "Group by category x province", cat_prov)
by_cat <- day_du %>% group_by(category) %>% tong_hop() %>% arrange(desc(net_revenue))
by_prov <- day_du %>% group_by(province) %>% tong_hop() %>% arrange(desc(avg_delivery_days))
by_month <- day_du %>% group_by(order_month) %>% tong_hop() %>% arrange(order_month)
by_bucket <- day_du %>% group_by(revenue_bucket) %>% tong_hop() %>% arrange(revenue_bucket)
ghi_buoc("B6", "Group by category", by_cat)
ghi_buoc("B6", "Group by province", by_prov)
ghi_buoc("B6", "Group by order_month", by_month)
ghi_buoc("B6", "Group by revenue_bucket", by_bucket)

# KPI tong (B7 - o so lieu tren dashboard)
kpi <- day_du %>% mutate(tat_ca = "Tong") %>% group_by(tat_ca) %>% tong_hop() %>%
  select(-tat_ca)
stopifnot(kpi$orders == 14408, kpi$returned == 1114, abs(kpi$net_revenue - 78218341.22) < 0.01)

write_csv(cat_prov, file.path(OUT_DIR, "dashboard_category_province.csv"))
write_csv(by_cat, file.path(OUT_DIR, "dashboard_category.csv"))
write_csv(by_prov, file.path(OUT_DIR, "dashboard_province.csv"))
write_csv(by_month, file.path(OUT_DIR, "dashboard_month.csv"))
write_csv(by_bucket, file.path(OUT_DIR, "dashboard_revenue_bucket.csv"))
write_csv(kpi, file.path(OUT_DIR, "kpi.csv"))
write_csv(buoc, file.path(OUT_DIR, "buoc_bigsheets.csv"))
print(kpi)

# =============================================================================
# B7-B8. Bieu do + dashboard
# =============================================================================
cat("== B7-B8: bieu do\n")
tb_tra <- 100 * kpi$returned / kpi$orders
NHAN_TB <- "Cao hơn trung bình"

p_kpi <- function() {
  o <- tibble(x = 1:4,
              nhan = c("Doanh thu ròng", "Tỷ lệ hoàn trả", "Thời gian giao TB", "Đơn giao > 5 ngày"),
              gia_tri = c(so_vn(kpi$net_revenue, 0), paste0(so_vn(kpi$return_rate_pct, 2), "%"),
                          paste(so_vn(kpi$avg_delivery_days, 2), "ngày"),
                          paste0(so_vn(kpi$late_pct, 2), "%")),
              phu = c(paste(so_vn(kpi$orders), "đơn sạch"), paste(so_vn(kpi$returned), "đơn bị trả"),
                      "từ lúc đặt tới lúc nhận", paste(so_vn(kpi$late_orders), "đơn")))
  ggplot(o) +
    geom_rect(aes(xmin = x - 0.47, xmax = x + 0.47, ymin = 0, ymax = 1),
              fill = "white", colour = MAU$luoi, linewidth = 0.6) +
    geom_text(aes(x = x - 0.42, y = 0.78, label = nhan), hjust = 0, family = FONT,
              colour = MAU$chu2, size = 5) +
    geom_text(aes(x = x - 0.42, y = 0.46, label = gia_tri), hjust = 0, family = FONT,
              colour = MAU$chu, size = 9, fontface = "bold") +
    geom_text(aes(x = x - 0.42, y = 0.16, label = phu), hjust = 0, family = FONT,
              colour = MAU$chu2, size = 4.2) +
    scale_x_continuous(limits = c(0.5, 4.5), expand = c(0, 0)) +
    scale_y_continuous(limits = c(0, 1), expand = c(0, 0)) +
    theme_void(base_family = FONT) +
    theme(plot.background = element_rect(fill = MAU$nen, colour = NA))
}

p_dt_cat <- function(co = 13) {
  ggplot(by_cat, aes(x = net_revenue / 1e6, y = reorder(category, net_revenue))) +
    geom_col(fill = MAU$xanh, width = 0.65) +
    geom_text(aes(label = so_vn(net_revenue / 1e6, 2)), hjust = -0.15, family = FONT,
              colour = MAU$chu, size = co / 3.2) +
    scale_x_continuous(expand = expansion(mult = c(0, 0.15)), labels = nhan_so(0)) +
    labs(title = "Doanh thu ròng theo danh mục", subtitle = "Triệu đơn vị tiền tệ", x = NULL, y = NULL) +
    theme_btl(co)
}

p_tra_cat <- function(co = 13) {
  d <- by_cat %>% mutate(nhom = ifelse(return_rate_pct > tb_tra, NHAN_TB, "Không cao hơn TB"))
  ggplot(d, aes(x = return_rate_pct, y = reorder(category, return_rate_pct), fill = nhom)) +
    geom_col(width = 0.65) +
    geom_vline(xintercept = tb_tra, linetype = "dashed", colour = MAU$chu2) +
    geom_text(aes(label = paste0(so_vn(return_rate_pct, 2), "%")), hjust = -0.15,
              family = FONT, colour = MAU$chu, size = co / 3.2) +
    scale_fill_manual(values = setNames(c(MAU$cam, MAU$xanh), c(NHAN_TB, "Không cao hơn TB")),
                      name = NULL) +
    scale_x_continuous(expand = expansion(mult = c(0, 0.18)), labels = nhan_so(1)) +
    labs(title = "Tỷ lệ hoàn trả theo danh mục",
         subtitle = paste0("Nét đứt: trung bình chung ", so_vn(tb_tra, 2), "%"), x = "%", y = NULL) +
    theme_btl(co)
}

p_giao_tinh <- function(co = 13) {
  tb <- kpi$avg_delivery_days
  ggplot(by_prov, aes(x = avg_delivery_days, y = reorder(province, avg_delivery_days))) +
    geom_col(fill = MAU$xanh, width = 0.65) +
    geom_vline(xintercept = tb, linetype = "dashed", colour = MAU$chu2) +
    geom_text(aes(label = paste0(so_vn(avg_delivery_days, 2), " ngày · trễ ", so_vn(late_pct, 1), "%")),
              hjust = -0.05, family = FONT, colour = MAU$chu, size = co / 3.6) +
    scale_x_continuous(expand = expansion(mult = c(0, 0.45)), labels = nhan_so(0)) +
    labs(title = "Thời gian giao trung bình theo tỉnh giao hàng",
         subtitle = paste0("Nhãn: số ngày TB · % đơn > 5 ngày; nét đứt: TB chung ", so_vn(tb, 2), " ngày"),
         x = "Ngày", y = NULL) +
    theme_btl(co)
}

p_heat <- function(co = 13) {
  d <- cat_prov %>% mutate(nhan = so_vn(return_rate_pct, 1))
  ggplot(d, aes(x = category, y = reorder(province, desc(province)), fill = return_rate_pct)) +
    geom_tile(colour = MAU$nen, linewidth = 1) +
    geom_text(aes(label = nhan, colour = return_rate_pct > 9.5), family = FONT, size = co / 3.6) +
    scale_colour_manual(values = c(`TRUE` = "white", `FALSE` = MAU$chu), guide = "none") +
    scale_fill_gradientn(colours = MAU$day, name = "% hoàn trả", labels = nhan_so(1)) +
    scale_x_discrete(position = "top") +
    labs(title = "Tỷ lệ hoàn trả (%) theo danh mục × tỉnh giao hàng",
         subtitle = paste0("Mỗi ô chỉ có ", min(d$orders), "–", max(d$orders),
                           " đơn, nên chênh lệch vài điểm % có thể do ngẫu nhiên"),
         x = NULL, y = NULL) +
    theme_btl(co) + theme(panel.grid = element_blank(), legend.position = "right")
}

p_thang <- function(co = 13) {
  d <- by_month %>%
    transmute(thang = as.Date(paste0(order_month, "-01")),
              `Doanh thu ròng (triệu)` = net_revenue / 1e6,
              `Tỷ lệ hoàn trả (%)` = return_rate_pct) %>%
    pivot_longer(-thang, names_to = "chi_so", values_to = "gia_tri")
  ggplot(d, aes(thang, gia_tri)) +
    geom_line(colour = MAU$xanh, linewidth = 0.9) +
    geom_point(colour = MAU$xanh, size = 1.8) +
    facet_wrap(~chi_so, ncol = 1, scales = "free_y") +
    scale_y_continuous(labels = nhan_so(1)) +
    scale_x_date(date_labels = "%m/%Y", date_breaks = "3 months") +
    labs(title = "Xu hướng theo tháng (01/2025 – 07/2026)", x = NULL, y = NULL) +
    theme_btl(co) + theme(panel.grid.major.y = element_line(colour = MAU$luoi, linewidth = 0.4),
                          strip.text = element_text(hjust = 0, face = "bold", colour = MAU$chu))
}

luu_anh(p_dt_cat() + labs(caption = "Nguồn: orders.csv, 14.408 đơn sạch. Lệnh: Rscript cau08_bigsheets/dashboard.R"),
        "cau08-doanh-thu-danh-muc.png")
luu_anh(p_tra_cat(), "cau08-hoan-tra-danh-muc.png")
luu_anh(p_giao_tinh(), "cau08-giao-hang-tinh.png", cao = 1100)
luu_anh(p_heat(), "cau08-heatmap-hoan-tra.png", cao = 1300)
luu_anh(p_thang(), "cau08-xu-huong-thang.png")

# Dashboard ghep bang grid (khong co patchwork/gridExtra trong anh R)
f <- file.path(IMG_DIR, "cau08-dashboard.png")
ragg::agg_png(f, width = 2600, height = 1700, res = 150, background = MAU$nen)
grid.newpage()
pushViewport(viewport(layout = grid.layout(4, 3, heights = unit(c(0.06, 0.14, 0.38, 0.42), "npc"),
                                           widths = unit(c(0.34, 0.33, 0.33), "npc"))))
o <- function(r, c) viewport(layout.pos.row = r, layout.pos.col = c)
grid.rect(gp = gpar(fill = MAU$nen, col = NA))
pushViewport(o(1, 1:3))
grid.text("Dashboard TMĐT: doanh thu – hoàn trả – giao hàng theo danh mục và tỉnh",
          x = 0.01, hjust = 0, gp = gpar(fontfamily = FONT, fontsize = 20, fontface = "bold"))
grid.text("14.408 đơn sạch (01/2025 – 07/2026) · mô phỏng BigSheets bằng R/ggplot2",
          x = 0.99, hjust = 1, gp = gpar(fontfamily = FONT, fontsize = 12, col = MAU$chu2))
popViewport()
print(p_kpi(), vp = o(2, 1:3))
print(p_heat(11) + theme(legend.position = "bottom"), vp = o(3:4, 1))
print(p_dt_cat(11), vp = o(3, 2))
print(p_tra_cat(11), vp = o(3, 3))
print(p_giao_tinh(11), vp = o(4, 2))
print(p_thang(11), vp = o(4, 3))
invisible(dev.off())
cat("  anh:", f, "\n")
cat("Xong. Font bieu do:", FONT, "\n")
