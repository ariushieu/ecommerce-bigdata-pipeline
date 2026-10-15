### Mã nguồn Câu 4, 5 – Nguyễn Tiến Hiệp

Mục này trích mã chính của Câu 4 (`src/cau04_pig/cau04.pig`, 254 dòng) và Câu 5 (`src/cau05_mapreduce/java/btl/cau05/`, 7 tệp), kèm các bảng chi tiết bổ sung cho mục 3.5 và 4.1.

**C.1. Pig – lọc, tách và ghi vùng staging** (`cau04.pig`, dòng 57–90)

```pig
orders_chk = FOREACH orders_raw GENERATE *,
    (record_id MATCHES '.*record_id' ? 'HEADER' :        -- dong tieu de co BOM
     ((order_id IS NULL OR ... OR net_revenue IS NULL OR quality_flag IS NULL ...)
      ? 'INVALID' : quality_flag)) AS status;
valid = FILTER orders_chk BY status != 'HEADER' AND status != 'INVALID';
SPLIT valid INTO clean IF quality_flag IN ('OK', 'MISSING'), rejected OTHERWISE;
staging = FOREACH clean GENERATE record_id, ..., (int) delivery_days AS delivery_days,
    returned_flag, review_score,                                      -- rong giu NULL
    ((campaign_id IS NULL OR campaign_id == '') ? 'NONE' : campaign_id) AS campaign_id,
    quality_flag, SUBSTRING(order_ts, 0, 7) AS order_month;
STORE staging INTO '$STAGING' USING PigStorage('\t', '-schema');
```

**C.2. Pig – JOIN với hai bảng danh mục và GROUP theo danh mục × phân khúc** (dòng 104–141)

```pig
j_cust = JOIN orders_c BY customer_id, customers BY customer_id USING 'replicated';
j_prod = JOIN j_cust BY orders_c::product_id, products BY product_id USING 'replicated';
g_seg = GROUP enriched BY (category, customer_segment);
seg_stats = FOREACH g_seg {
    custs = DISTINCT enriched.customer_id;
    rets  = FILTER enriched BY returned_flag == 1;
    GENERATE group.category AS category, group.customer_segment AS customer_segment,
        COUNT(enriched) AS orders, SIZE(custs) AS customers,
        SUM(enriched.revenue_cents) AS revenue_cents, COUNT(rets) AS returned,
        ROUND_TO(AVG(enriched.net_revenue), 2) AS avg_order_value,
        MIN(enriched.net_revenue) AS min_order_value, MAX(enriched.net_revenue) AS max_order_value;
};
```

**C.3. MapReduce – Mapper** (`RevenueMapper.java`, rút gọn)

```java
String line = value.toString();
if (!line.isEmpty() && line.charAt(0) == BOM) line = line.substring(1);
if (line.startsWith("record_id,")) { ctx.getCounter(DataQuality.HEADER_SKIPPED).increment(1); return; }
String[] f = line.split(",", -1);
if (f.length != 23) { ctx.getCounter(DataQuality.MALFORMED).increment(1); return; }
switch (f[F_FLAG]) {                      // quy tac lam sach chung
    case "OUTLIER":   ctx.getCounter(DataQuality.DROP_OUTLIER).increment(1);   return;
    case "DUPLICATE": ctx.getCounter(DataQuality.DROP_DUPLICATE).increment(1); return;
    case "LATE":      ctx.getCounter(DataQuality.DROP_LATE).increment(1);      return;
    case "OK": case "MISSING": break;
    default: ctx.getCounter(DataQuality.MALFORMED).increment(1); return;
}
long cents = new BigDecimal(f[F_NET_REVENUE]).setScale(2, RoundingMode.HALF_UP)
        .unscaledValue().longValueExact();          // tien tinh bang xu, chinh xac
outKey.set(category + "\t" + province + "\t" + ts.substring(0, 7));
outVal.set(1, cents, ret);                          // OrderStats(orders, cents, returned)
ctx.write(outKey, outVal);
```

**C.4. MapReduce – Combiner, Partitioner, Reducer** (rút gọn)

```java
// StatsCombiner: chi cong (giao hoan, ket hop), cung kieu voi dau ra Mapper
sum.set(0, 0, 0);
for (OrderStats v : values) sum.add(v);
ctx.write(key, sum);

// CategoryPartitioner: ca danh muc ve 1 reducer, bang anh xa theo khoang chu cai
Integer p = mapping.get(categoryOf(key));   // Beauty,Books->0; Electronics,Fashion->1; Home,Sports->2
return (p != null && p < numPartitions) ? p
        : (categoryOf(key).hashCode() & Integer.MAX_VALUE) % numPartitions;

// RateReducer: cong roi moi chia; lam tron HALF_UP bang so nguyen
long rateX100 = (20000L * ret + n) / (2L * n);
outVal.set(n + "\t" + formatHundredths(cents) + "\t" + ret + "\t" + formatHundredths(rateX100));
```

**C.5. Lệnh chạy** (trong `ssh may1`, thư mục `~/src`)

```bash
bash cau04_pig/run.sh && bash cau04_pig/test.sh
bash cau05_mapreduce/run.sh && bash cau05_mapreduce/test.sh
bash cau05_mapreduce/bench.sh   # co/khong Combiner, 3 lan
```

**C.6. Toán tử và hàm Pig Latin trong `cau04.pig`** (bổ sung cho mục 3.5.1)

*[Bảng:c04-toan-tu]. Toán tử Pig Latin theo yêu cầu đề và vị trí trong `cau04.pig`*

| Toán tử | Dòng | Mục đích |
|---|---|---|
| LOAD + schema | 27, 36, 41, 46 | 3 CSV (`PigStorage`), JSON Lines (`JsonLoader`) |
| FILTER | 68, 101–102 | Bỏ tiêu đề BOM, bản ghi không hợp lệ |
| SPLIT | 73 | Tách đơn giữ (OK, MISSING) và đơn loại |
| FOREACH | 57, 80, 93, 107, 126… | Gắn trạng thái, chuẩn hóa; FOREACH lồng |
| JOIN | 104–105, 215 | `customers`, `products` (`USING 'replicated'`); sự kiện với đơn (LEFT OUTER) |
| GROUP | 125, 158, 178, 192, 223, 236 | Theo phân khúc, danh mục, sản phẩm, tháng |
| DISTINCT | 127, 160 (lồng), 244 | Đếm khách; kiểm tra trùng 20 cột |
| ORDER | 150, 167, 203 (lồng), 182 | Sắp kết quả |
| LIMIT | 183 | 10 sản phẩm doanh thu cao nhất |
| STORE | 89–90, 155, 173, 186, 206, 226, 254 | 8 đầu ra |

**Nhận xét [Bảng:c04-toan-tu]:** Đủ 10 nhóm toán tử đề yêu cầu, thêm UNION (dòng 253) và FLATTEN; ORDER cấp quan hệ chỉ dùng cho top 10.

*[Bảng:c04-ham]. Hàm đánh giá dùng trong `cau04.pig`*

| Hàm | Dòng | Dùng để |
|---|---|---|
| COUNT, SUM | 133, 135, 136, 161–162, 194–195 | Số đơn, doanh thu (xu), số đơn trả |
| AVG | 137, 140–141, 163 | Giá trị đơn, ngày giao, điểm (bỏ qua NULL) |
| MIN / MAX | 138–139, 181 | Đơn nhỏ nhất/lớn nhất; điểm sản phẩm |
| SIZE | 61, 134, 161 | Độ dài chuỗi thời gian; số khách khác nhau |
| CONCAT | 132, 237 | Khóa `category|segment`; tên chỉ số |
| SUBSTRING, REPLACE | 87, 212 | Tháng `YYYY-MM`; bỏ tiền tố `EVT-` |
| ROUND, ROUND_TO, SPRINTF | 95, 137, 144, 200 | Đổi sang xu; làm tròn; định dạng `%d.%02d` |

**Nhận xét [Bảng:c04-ham]:** 12 hàm dựng sẵn, đủ các hàm đề gợi ý trừ TOKENIZE (không có văn bản tự do).

**C.7. MapReduce – lần theo một khóa và so sánh cách chia phân vùng** (bổ sung cho mục 3.5.2)

*[Bảng:c05-vi-du]. Lần theo một khóa qua các bước MapReduce*

| Bước | Dữ liệu |
|---|---|
| Dòng vào (4 dòng) | `ORD0001791` …,1603.02,…,1,…,OK · `ORD0004380` …,2616.7,…,0,…,OK · `ORD0004417` …,1423.84,…,0,…,**DUPLICATE** · `ORD0011491` …,4455.45,…,0,…,OK |
| Map ra (3 cặp) | (`Beauty⇥Can Tho⇥2026-04`, (1, 160302, 1)) · (…, (1, 261670, 0)) · (…, (1, 445545, 0)); `ORD0004417` chỉ tăng Counter `DROP_DUPLICATE` |
| Combine ra | (`Beauty⇥Can Tho⇥2026-04`, (3, 867517, 1)) |
| Partition | `Beauty` → reducer 0 |
| Reduce ra | `Beauty⇥Can Tho⇥2026-04⇥3⇥8675.17⇥1⇥33.33`, với tỷ lệ × 100 = (20000 × 1 + 3) div (2 × 3) = 3333 |

**Nhận xét [Bảng:c05-vi-du]:** Dòng kết quả trùng với `output/category_province_month.tsv`. Công thức `(20000·r + n) div (2n)` bằng ⌊10000·r/n + 0,5⌋, tức làm tròn HALF_UP chỉ bằng số nguyên.

*[Bảng:c05-phan-vung]. Tải của 3 reducer theo cách chia (số đơn sạch / số khóa)*

| Cách chia | Reducer 0 | Reducer 1 | Reducer 2 | Lệch tải (max/TB) |
|---|---|---|---|---:|
| (a) `CategoryPartitioner` (bảng ánh xạ) | 5.172 / 682 | 4.340 / 683 | 4.896 / 684 | 1,077 |
| (b) `hash(category) mod 3` | 10.293 / 1.366 | 4.115 / 683 | 0 / 0 | 2,143 |
| (c) `HashPartitioner` trên cả khóa | 4.872 / 690 | 4.801 / 680 | 4.735 / 679 | 1,014 |

**Nhận xét [Bảng:c05-phan-vung]:** Cách (c) cân bằng nhất nhưng rải mỗi danh mục ra cả 3 tệp; với Combiner, tải thực tế của (a) là số khóa (682/683/684). Bảng ánh xạ đổi được bằng `-D cau05.partition.map=…`.

**C.8. Kiểm thử Câu 4 và kết quả chi tiết** (mục 3.5.1, 4.1)

*[Bảng:c04-kiem-thu]. Trường hợp kiểm thử của Câu 4 (`bash test.sh`, khoảng 12 giây)*

| # | Dữ liệu vào | Kết quả mong đợi | Kết quả |
|---|---|---|---|
| TC1 | 1 tiêu đề BOM; 2 dòng hỏng; 18 OK, 1 MISSING, 1 OUTLIER, 1 DUPLICATE, 1 LATE | HEADER 1, INVALID 2; giữ 19, loại 3 | PASS |
| TC2 | 19 đơn sạch | 7 dòng; `Books,2025-01` = 3100.30, 50.00%; 2/3 → 66.67 | PASS |
| TC3 | Vùng staging | 19 dòng × 24 cột; không còn BOM/CR; `campaign_id = NONE` | PASS |
| TC4 | 5 sự kiện JSON | Đúng 1 sự kiện lệch, 1 sự kiện không có đơn | PASS |
| TC5 | `compare_category_month.csv` thật | 114 ô; 14.408 đơn, 78.218.341,22, 1.114 đơn trả | PASS |
| TC6 | Tệp Câu 4 và Câu 5 | Giống hệt từng byte (`diff`) | PASS |

**Nhận xét [Bảng:c04-kiem-thu]:** TC1–TC4 kiểm tra logic trên ca biên tính tay; TC5–TC6 báo lỗi nếu sửa kịch bản mà quên chạy lại `run.sh`.

*[Bảng:c04-kq-phan-khuc]. Doanh thu ròng theo danh mục × phân khúc khách hàng (`segment_stats.tsv`)*

| Danh mục | Loyal | New | Regular | VIP |
|---|---:|---:|---:|---:|
| Beauty | 2.965.366,55 | 3.008.979,39 | 2.611.058,27 | 2.841.221,53 |
| Books | **4.188.020,25** | 4.074.021,12 | 3.950.340,52 | 3.529.601,94 |
| Electronics | 3.489.757,81 | 3.455.277,15 | 3.695.033,04 | 3.446.658,93 |
| Fashion | *2.111.320,42* | 2.637.522,29 | 2.462.405,06 | 2.500.202,34 |
| Home | 3.600.387,79 | 3.785.740,80 | 3.417.710,28 | 3.453.461,71 |
| Sports | 3.118.603,92 | 3.544.279,58 | 3.118.900,05 | 3.212.470,48 |

**Nhận xét [Bảng:c04-kq-phan-khuc]:** Cao nhất Books × Loyal (772 đơn), thấp nhất Fashion × Loyal (412 đơn, tỷ lệ trả 9,47%).

*[Bảng:c05-kq-tinh]. Doanh thu và tỷ lệ trả theo tỉnh giao hàng, gộp từ đầu ra MapReduce (`province_summary.tsv`)*

| Tỉnh giao | Đơn | Doanh thu ròng | Đơn trả | Tỷ lệ trả (%) |
|---|---:|---:|---:|---:|
| Khanh Hoa | 841 | 4.701.770,56 | 55 | 6,54 |
| Nam Dinh | 837 | 4.669.197,53 | 76 | 9,08 |
| TP Ho Chi Minh | 840 | 4.611.342,95 | 59 | 7,02 |
| Quang Nam | 823 | 4.531.936,01 | 75 | 9,11 |
| Da Nang | 816 | 4.493.772,23 | 60 | 7,35 |
| Thua Thien Hue | 819 | 4.390.161,50 | 55 | 6,72 |
| Thai Nguyen | 808 | 4.387.558,73 | 59 | 7,30 |
| Binh Duong | 800 | 4.386.709,54 | 61 | 7,62 |
| Ha Noi | 786 | 4.362.931,19 | 67 | 8,52 |
| Hai Duong | 791 | 4.289.781,99 | 67 | 8,47 |
| Quang Ninh | 784 | 4.265.168,47 | 57 | 7,27 |
| Hai Phong | 827 | 4.256.831,71 | 64 | 7,74 |
| Lam Dong | 772 | 4.243.753,37 | 60 | 7,77 |
| Nghe An | 801 | 4.229.799,14 | 47 | 5,87 |
| Bac Ninh | 769 | 4.214.587,48 | 59 | 7,67 |
| Thanh Hoa | 797 | 4.193.213,55 | 64 | 8,03 |
| Dong Nai | 760 | 4.120.715,48 | 68 | 8,95 |
| Can Tho | 737 | 3.869.109,79 | 61 | 8,28 |

**Nhận xét [Bảng:c05-kq-tinh]:** Doanh thu đều giữa 18 tỉnh; tỷ lệ trả thấp nhất Nghe An (5,87%), cao nhất Quang Nam (9,11%).
