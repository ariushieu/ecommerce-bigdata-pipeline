### Mã nguồn – thành viên D

Mã đầy đủ nằm trong `src/cau06_spark/` (Câu 6) và `src/cau07_hbase/` (Câu 7). Dưới đây là các đoạn quan trọng nhất; chú thích trong mã viết không dấu theo quy ước của nhóm.

*[Bảng:c06-tep-ma-nguon]. Các tệp mã nguồn của Câu 6 và Câu 7*

| Tệp | Nội dung |
|---|---|
| `cau06_spark/pipeline.py` | Pipeline PySpark: đọc raw, làm sạch, join, cache, 4 phân tích, ghi curated và kết quả |
| `cau06_spark/bench.py` | Thử nghiệm cache / số phân vùng shuffle / quy mô ×1, ×10 (mục 4.4) |
| `cau06_spark/category_month_only.py` | Bản Spark của đúng một job MapReduce (danh mục × tháng) để so thời gian |
| `cau06_spark/run.sh`, `test.sh` | Chạy pipeline (`--bench`, `--cm-only`); kiểm thử CI so kết quả với `output/` |
| `cau07_hbase/CustomerOrders.java` | Java Client API: create (pre-split, TTL, SNAPPY), load (BufferedMutator), get, scan tiền tố, phiên bản, delete, selftest |
| `cau07_hbase/shell_demo.rb` | Lệnh hbase shell: describe, get/scan/put/delete, VERSIONS, TIMERANGE, TTL, snapshot, clone, grant |
| `cau07_hbase/run.sh`, `test.sh` | Tạo + nạp bảng thật, demo, ACL, ExportSnapshot, đo nén; kiểm thử CI trên bảng tạm |

**Nhận xét [Bảng:c06-tep-ma-nguon]:** mọi tệp chạy được trong `ssh may1` bằng một lệnh; kết quả nhỏ được ghi vào `output/` để báo cáo trích dẫn và `test.sh` kiểm tra lại ở mỗi lần CI.

**1. Làm sạch và tạo cột mới (`pipeline.py`, hàm `clean_orders`)** – lọc theo nhãn, ô trống thành NULL, chốt kiểu, tạo cột thời gian và tiền:

```python
def clean_orders(orders):
    y0, m0 = FIRST_MONTH
    blank_to_null = lambda c: F.when(F.trim(F.col(c)) == "", F.lit(None)).otherwise(F.trim(F.col(c)))
    return (orders
            .withColumn("quality_flag", F.upper(F.trim("quality_flag")))
            .filter(~F.col("quality_flag").isin(BAD_FLAGS))                      # T1 filter
            .withColumn("campaign_id", blank_to_null("campaign_id"))             # '' -> NULL
            .withColumn("order_ts", F.to_timestamp("timestamp", TS_FMT))         # T2 chuoi -> TIMESTAMP
            .withColumn("delivery_days", F.col("delivery_days").cast("int"))
            .withColumn("year", F.year("order_ts"))
            .withColumn("month", F.lpad(F.month("order_ts").cast("string"), 2, "0"))
            .withColumn("ym", F.date_format("order_ts", "yyyy-MM"))
            .withColumn("month_idx", (F.year("order_ts") - y0) * 12 + F.month("order_ts") - m0)
            ...
            .drop("timestamp", "record_id"))
```

**2. Join broadcast và cờ đối chiếu luồng (`enrich`)** – danh mục nhỏ được gửi tới mọi executor, sự kiện chỉ dùng để gắn cờ:

```python
seen = events.select(F.regexp_replace("event_id", "^EVT-", "").alias("order_id")) \
             .distinct().withColumn("seen_in_stream", F.lit(True))
return (clean
        .join(F.broadcast(prod), "product_id", "left")                           # T3 join
        .join(F.broadcast(cust), "customer_id", "left")
        .join(F.broadcast(seen), "order_id", "left")
        .fillna(False, subset=["seen_in_stream"]) ...)
```

**3. Cache, action và ghi vùng curated (`run`, `main`)**:

```python
enriched = enrich(clean, customers, products, events)
enriched.persist(StorageLevel.MEMORY_AND_DISK)      # dung lai cho >= 5 action phia sau
res["n_clean"] = enriched.count()                   # A1: 14.408, vat chat hoa cache
...
(enriched.repartition("year", "month", "category")  # T7: moi phan vung 1 tep
 .write.mode("overwrite").partitionBy("year", "month", "category")
 .parquet("/btl/curated/orders"))                   # A8
enriched.unpersist()
```

**4. Tăng trưởng sản phẩm (`product_growth`)** – lưới sản phẩm × tháng, so sánh hai cửa sổ, độ dốc và kiểm định z:

```python
grid = products.select("product_id", "category", "brand").crossJoin(months)    # T5
series = grid.join(monthly, ["product_id", "month_idx"], "left").fillna(0, ["rev", "qty", "n"])
g = series.groupBy("product_id", "category", "brand").agg(
        F.sum(F.when(in_r, F.col("rev")).otherwise(0)).alias("rev_recent"), ...,
        (F.covar_pop("month_idx", "rev") / F.var_pop("month_idx")).alias("slope"))
g = g.withColumn("z_orders", (F.col("orders_recent") - F.col("orders_prev"))
                 / F.sqrt(F.greatest(F.col("orders_recent") + F.col("orders_prev"), F.lit(1))))
```

**5. RowKey và Put của HBase (`CustomerOrders.java`)** – timestamp của ô là thời điểm nghiệp vụ; `d:status` có nhiều phiên bản:

```java
static String rowKey(String customerId, long tsMillis) {
    return customerId + "#" + String.format("%019d", Long.MAX_VALUE - tsMillis);
}
...
long ts = eventMillis(f[1]);                              // gio dat hang (+07:00)
Put p = new Put(Bytes.toBytes(rowKey(f[7], ts)));
add(p, O, "order_id", ts, f[6]);
add(p, M, "net_revenue", ts, f[16]);
add(p, D, "status", ts, "PLACED");
add(p, D, "status", delivered, "DELIVERED");              // ts + delivery_days ngay
if ("1".equals(f[19].trim())) add(p, D, "status", delivered + 1, "RETURNED");
```

**6. Tạo bảng có pre-split, TTL, nén và đọc đơn mới nhất của một khách**:

```java
ColumnFamilyDescriptorBuilder.newBuilder(name).setMaxVersions(versions)
        .setTimeToLive(TTL_SECONDS)                                   // 3 nam
        .setCompressionType(Compression.Algorithm.SNAPPY)
        .setBloomFilterType(BloomType.ROW)
        .setDataBlockEncoding(DataBlockEncoding.FAST_DIFF).build();
admin.createTable(td, splits);                                        // C00201 .. C01001 -> 6 region

Scan s = new Scan().setStartStopRowForPrefixScan(Bytes.toBytes(customerId + "#")).setLimit(n);
```

**7. Schema của bảng curated `orders`** (đọc lại từ `/btl/curated/orders/`, trích `pipeline_log.txt`; dẫn từ mục 2.5):

*[Bảng:c06-schema-curated]. Schema của bảng curated `orders` (45 cột)*

| Nhóm | Cột (kiểu) |
|---|---|
| Khóa | `order_id`, `customer_id`, `product_id` (STRING) |
| Chiều phân tích gốc | `province` (tỉnh giao hàng), `source_system`, `ingest_mode`, `data_format`, `customer_segment`, `sales_channel`, `payment_method` (STRING) |
| Độ đo gốc | `quantity` (INT), `unit_price`, `discount_rate`, `shipping_fee`, `net_revenue` (DOUBLE) |
| Kết quả vận hành | `delivery_days` (INT, đã ép kiểu), `returned_flag` (INT), `review_score` (INT, cho phép NULL) |
| Khác | `campaign_id` (STRING, cho phép NULL), `quality_flag` (STRING: OK/MISSING) |
| **Mới – thời gian** | `order_ts` (TIMESTAMP), `order_date` (DATE), `ym` (STRING `YYYY-MM`), `month_idx` (INT, 0 = 01/2025), `hour` (INT) |
| **Mới – tiền** | `gross_amount`, `discount_amount` (DOUBLE) |
| **Mới – cờ** | `has_review`, `has_campaign`, `seen_in_stream`, `ship_to_home` (BOOLEAN) |
| **Mới – từ `products`** | `brand`, `supplier_id` (STRING), `product_rating` (DOUBLE), `product_active` (INT) |
| **Mới – từ `customers`** | `home_province`, `age_group`, `gender`, `preferred_channel` (STRING), `join_date` (DATE), `loyalty_score` (INT), `tenure_days` (INT) |
| Cột phân vùng (nằm trên đường dẫn) | `year` (INT), `month` (thư mục `month=MM`), `category` (STRING) |

**Nhận xét [Bảng:c06-schema-curated]:** 21 cột gốc cộng 24 cột mới; các phân tích phía sau (Câu 6, dashboard, R) đọc thẳng vùng curated mà không phải join lại.

**8. Lịch sử phiên bản `d:status` trong hbase shell** (`src/cau07_hbase/output/shell_demo.txt`, đơn bị trả ORD0013507; shell hiển thị giờ UTC, sớm hơn giờ Việt Nam 7 giờ; dẫn từ mục 3.2.2):

```
get 'btl:customer_orders', 'C00941#9223370277765036807', {COLUMN => 'd:status', VERSIONS => 5}
 d:status timestamp=2025-09-30T20:02:19.001, value=RETURNED
 d:status timestamp=2025-09-30T20:02:19, value=DELIVERED
 d:status timestamp=2025-09-28T20:02:19, value=PLACED
get ... {COLUMN => 'd:status', TIMERANGE => [ms('2025-09-29T00:00:00'), ms('2025-10-01T00:00:00')], VERSIONS => 5}
 d:status timestamp=2025-09-28T20:02:19, value=PLACED
```

Thêm phiên bản `REFUNDED` với timestamp 05/10/2025 thì `get` mặc định trả `REFUNDED`; `delete` đúng timestamp đó thì lịch sử quay về 3 phiên bản. Phiên bản thứ 6 trở đi bị loại khi compaction.

**9. Truy vấn Spark SQL danh mục × tháng** (`pipeline.py`; dẫn từ mục 3.4.3):

```sql
SELECT category, ym AS month, COUNT(*) AS orders,
       CAST(SUM(CAST(net_revenue AS DECIMAL(14,2))) AS DECIMAL(16,2)) AS net_revenue,
       SUM(returned_flag) AS returned,
       ROUND(100.0 * SUM(returned_flag) / COUNT(*), 2) AS return_rate_pct
FROM orders_clean GROUP BY category, ym ORDER BY category, month
```

**10. Ví dụ đơn trước và sau xử lý** (dẫn từ mục 2.4.2):

*[Bảng:c06-truoc-sau]. Ví dụ hai đơn trước và sau xử lý (trích `pipeline_log.txt`)*

| Trường | ORD0000002 – trước | ORD0000002 – sau | ORD0000014 – sau |
|---|---|---|---|
| Thời điểm | `2025-10-12T22:41:50` (chuỗi) | `2025-10-12 22:41:50` (TIMESTAMP) | `2025-01-20 07:52:06` |
| `ym` / `month_idx` | – | `2025-10` / 9 | `2025-01` / 0 |
| `delivery_days` | `3.0` (DOUBLE) | `3` (INT) | `3` |
| `review_score` / `has_review` | rỗng | NULL / false | 2 / true |
| `brand` / `home_province` | – | Brand-40 / Hai Phong | Brand-25 / Da Nang |
| `seen_in_stream` | – | true | true |

**Nhận xét [Bảng:c06-truoc-sau]:** `review_score` rỗng được giữ là NULL nên không kéo thấp điểm trung bình; `home_province` của ORD0000002 (Hai Phong) khác tỉnh giao hàng (Lam Dong).

**11. Phân bố dòng HBase sau pre-split** (`src/cau07_hbase/output/load.txt`; dẫn từ mục 3.2.2):

*[Bảng:c07-pre-split]. Phân bố dòng trên 6 region sau khi nạp 14.408 đơn*

| Region (khoảng rowkey) | RegionServer | Số dòng | Số khách |
|---|---|---:|---:|
| (đầu) .. C00201 | datanode2 | 2.384 | 200 |
| C00201 .. C00401 | datanode3 | 2.419 | 200 |
| C00401 .. C00601 | datanode1 | 2.444 | 200 |
| C00601 .. C00801 | datanode2 | 2.377 | 200 |
| C00801 .. C01001 | datanode1 | 2.332 | 200 |
| C01001 .. (cuối) | datanode3 | 2.452 | 200 |
| **Tổng** | | **14.408** | **1.200** |

**Nhận xét [Bảng:c07-pre-split]:** region lớn nhất chỉ hơn region nhỏ nhất 5,1%, mỗi RegionServer giữ đúng 2 region; khách mới (C01201 trở đi) rơi vào region cuối, HBase tự tách tiếp khi region lớn lên.

**12. Kiểm tra phân quyền HBase** (`src/cau07_hbase/output/acl_backup.txt`, user `hadoop` là superuser; dẫn từ mục 3.2.2):

*[Bảng:c07-quyen]. Kiểm tra phân quyền trên `btl:customer_orders`*

| Lệnh | Kết quả |
|---|---|
| `grant 'analyst', 'R', 'btl:customer_orders'` rồi `scan … LIMIT => 2` | Đọc được 2 dòng |
| analyst `put … 'o:order_id', 'HACK'` | `AccessDeniedException … action=WRITE` |
| `revoke 'analyst', 'btl:customer_orders'` rồi `scan` | `AccessDeniedException … action=READ` |

**Nhận xét [Bảng:c07-quyen]:** `AccessController` chặn đúng thao tác ngoài quyền được cấp, và thu hồi quyền có hiệu lực ngay.

**13. Tiêu chí phân tích của Câu 6** (`product_growth`, `customer_churn`; dẫn từ mục 3.4.3):
- *Tăng trưởng sản phẩm:* gộp theo `product_id × month_idx`; `growth_rev_pct = (rev_R − rev_P) / rev_P × 100` (tương tự cho số lượng); độ dốc 19 tháng `slope = covar_pop(month_idx, rev) / var_pop(month_idx)`; `z_orders = (n_R − n_P) / √(n_R + n_P)` (hiệu hai biến Poisson; |z| ≥ 1,96 là khó do ngẫu nhiên).
- *Rời bỏ:* `recency_days`, `frequency`, `monetary`, `avg_gap_days`; số đơn 6 tháng cuối so với 6 tháng trước; điểm R, F, M bằng `ntile(5)`. **MEDIUM** khi quá 90 ngày, hoặc quá max(60, 2 × `avg_gap_days`) ngày, hoặc số đơn giảm ít nhất một nửa (từ ≥ 4 đơn). Đường cơ sở Poisson: số khách *ngẫu nhiên* không mua trong 90 ngày là Σ exp(−90 × `frequency` / 577).
