# Câu 7 – HBase

**Yêu cầu:** Bảng truy cập ngẫu nhiên, RowKey `customer_id#reverse_timestamp`, ≥3 column families, version/timestamp, create/put/get/scan/delete, pre-split, TTL, nén, backup (snapshot), phân quyền.

**Phụ trách:** thành viên D (xem [phân công](../../README.md#phân-công-mỗi-người-20)). Quy ước chung: [`docs/quy-uoc.md`](../../docs/quy-uoc.md).

**Bài viết:** mục 1.4.3, 3.2.2 và Phụ lục B – `report/sections/14d-*.md`, `32b-*.md`, `96d-*.md`.

**Chạy (trong `ssh may1`, thư mục `~/src`):**

```bash
bash cau07_hbase/run.sh            # (~2 phut) tao lai btl:customer_orders, nap 14.408 don, demo, ACL, backup, do nen
bash cau07_hbase/test.sh           # CI: bien dich + selftest tren bang tam btl:customer_orders_selftest, roi xoa
hbase shell -n cau07_hbase/shell_demo.rb    # chi chay cac lenh hbase shell (bang that phai co san)
```

Dùng riêng Java Client API (biên dịch từ mã nguồn, `*.class` không commit):

```bash
cd cau07_hbase && mkdir -p /tmp/co && javac -cp "$(hbase classpath)" -d /tmp/co CustomerOrders.java
java -cp "/tmp/co:$(hbase classpath)" CustomerOrders latest C00941 5     # 5 don moi nhat
java -cp "/tmp/co:$(hbase classpath)" CustomerOrders history 'C00941#9223370277765036807'
# them: create [--recreate] | load - (doc stdin) | count | get | status | delete | flush | drop | selftest
# doi bang: java -Dtable=ns:ten ...
```

**Thiết kế bảng `btl:customer_orders`:**

| Thành phần | Lựa chọn |
|---|---|
| RowKey | `customer_id#(Long.MAX_VALUE − epoch_ms)` 19 chữ số, giờ +07:00 → đơn mới nhất đứng đầu khi scan tiền tố |
| CF `o` | Thông tin đơn (order_id, ts, product, category, segment, channel, payment, campaign, province, source, ingest_mode, quality_flag), VERSIONS 1 |
| CF `m` | Tiền (quantity, unit_price, discount_rate, shipping_fee, net_revenue), VERSIONS 1 |
| CF `d` | Giao hàng/phản hồi (delivery_days, returned_flag, review_score, `status` PLACED → DELIVERED → RETURNED), VERSIONS 5 |
| Timestamp | Thời điểm nghiệp vụ (đặt hàng / giao), không phải thời điểm nạp |
| TTL | 3 năm (94.608.000 s) tính theo timestamp ô → lưu trực tuyến 3 năm gần nhất |
| Nén | SNAPPY + FAST_DIFF + BLOOMFILTER ROW (nhỏ hơn 5,79 lần so với không nén) |
| Pre-split | `C00201, C00401, C00601, C00801, C01001` → 6 region, 2.332–2.452 dòng/region |
| Sao lưu | `snapshot` → `clone_snapshot` (kiểm 14.408 dòng) → `ExportSnapshot` ra `/btl/backup/hbase` |
| Quyền | `grant 'analyst','R'` (đọc được, ghi bị từ chối) → `revoke` (đọc bị từ chối) |

**Đầu ra trong `output/`:** `load.txt` (create, nạp, số dòng theo region), `client_api_demo.txt`, `shell_demo.txt`, `acl_backup.txt`, `compression.txt`.

**Lưu ý:**
- Nạp 14.408 đơn sạch (quy ước mục 2), giữ `o:quality_flag`; đọc `orders.csv` qua `hdfs dfs -cat … | java CustomerOrders load -` vì `hbase classpath` không có HDFS client.
- `run.sh` xóa và tạo lại bảng `btl:customer_orders` (của Câu 7), snapshot `customer_orders_snap` và `/btl/backup/hbase`; không đụng `btl:order_events` (Câu 2).
- Snapshot `customer_orders_snap` được giữ lại làm bản sao lưu.
