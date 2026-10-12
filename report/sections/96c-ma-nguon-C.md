### Mã nguồn – thành viên C

Mục này trích phần mã quan trọng nhất của Câu 4 (`src/cau04_pig/cau04.pig`, 254 dòng) và Câu 5 (`src/cau05_mapreduce/java/btl/cau05/`, 7 tệp: `RevenueMapper`, `StatsCombiner`, `CategoryPartitioner`, `RateReducer`, `OrderStats`, driver `RevenueReturnJob`, enum Counter `DataQuality`), kèm các bảng chi tiết bổ sung cho mục 3.5.

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
        CONCAT(group.category, '|', group.customer_segment) AS segment_key,
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
bash cau04_pig/run.sh          # Pig tren YARN -> /btl/staging/orders, /btl/output/cau04_pig
bash cau04_pig/test.sh         # 6 kiem thu (pig -x local)
bash cau05_mapreduce/run.sh    # build + 3 job MapReduce -> /btl/output/cau05_mr
bash cau05_mapreduce/bench.sh  # do thoi gian co/khong Combiner, 3 lan
bash cau05_mapreduce/test.sh   # 5 kiem thu (che do local)
```

**C.6. Toán tử và hàm Pig Latin trong `cau04.pig`** (bổ sung cho mục 3.5.1)

*[Bảng:c04-toan-tu]. Toán tử Pig Latin theo yêu cầu đề và vị trí trong `cau04.pig`*

| Toán tử | Dòng | Mục đích |
|---|---|---|
| LOAD + schema | 27, 36, 41, 46 | 3 CSV bằng `PigStorage(',')`, JSON Lines bằng `JsonLoader` (schema lồng `payload:(…)`) |
| FILTER | 68, 101–102 | Bỏ dòng tiêu đề có BOM và bản ghi không hợp lệ |
| SPLIT | 73 | Tách đơn giữ (OK, MISSING) và đơn loại |
| FOREACH | 57, 80, 93, 107, 126… | Gắn trạng thái, chuẩn hóa, tính cột mới; FOREACH lồng `{…}` |
| JOIN | 104–105, 215 | `customers`, `products` (`USING 'replicated'`); sự kiện với đơn (LEFT OUTER) |
| GROUP | 125, 158, 178, 192, 223, 236 | Theo `(category, customer_segment)`, danh mục, sản phẩm, `(category, month)` |
| DISTINCT | 127, 160 (lồng), 244 | Đếm khách khác nhau; kiểm tra trùng nội dung 20 cột |
| ORDER | 150, 167, 203 (lồng), 182 | Sắp kết quả |
| LIMIT | 183 | 10 sản phẩm doanh thu cao nhất |
| STORE | 89–90, 155, 173, 186, 206, 226, 254 | 8 đầu ra, `PigStorage('\t', '-schema')` |

**Nhận xét [Bảng:c04-toan-tu]:** Đủ 10 nhóm toán tử đề yêu cầu, thêm UNION (dòng 253) và FLATTEN; ORDER cấp quan hệ chỉ dùng ở dòng 182 (top 10), còn lại là ORDER lồng.

*[Bảng:c04-ham]. Hàm đánh giá dùng trong `cau04.pig`*

| Hàm | Dòng | Dùng để |
|---|---|---|
| COUNT, SUM | 133, 135, 136, 161–162, 194–195 | Số đơn, doanh thu (xu), số đơn trả |
| AVG | 137, 140–141, 163 | Giá trị đơn, ngày giao, điểm đánh giá trung bình (bỏ qua NULL) |
| MIN / MAX | 138–139, 181 | Đơn nhỏ nhất/lớn nhất; điểm sản phẩm |
| SIZE | 61, 134, 161 | Độ dài chuỗi thời gian; số khách khác nhau |
| CONCAT | 132, 237 | Khóa `category|segment`; tên chỉ số |
| SUBSTRING, REPLACE | 87, 212 | Tháng `YYYY-MM`; bỏ tiền tố `EVT-` |
| ROUND, ROUND_TO, SPRINTF | 95, 137, 144, 200 | Đổi sang xu; làm tròn; định dạng `%d.%02d` |

**Nhận xét [Bảng:c04-ham]:** Dùng 12 hàm dựng sẵn, đủ các hàm đề gợi ý trừ TOKENIZE (bộ dữ liệu không có văn bản tự do để tách từ).

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

**Nhận xét [Bảng:c05-phan-vung]:** Cách (a) lệch 7,7% về số đơn, nhưng khi có Combiner tải thực tế là số khóa (682/683/684); bảng ánh xạ đổi được bằng `-D cau05.partition.map=…`, không cần biên dịch lại.
