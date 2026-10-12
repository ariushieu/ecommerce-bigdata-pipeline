# Câu 4 – Pig Latin

**Yêu cầu:** LOAD + schema, FILTER, JOIN sự kiện với 2 bảng danh mục, GROUP theo category × customer_segment, FOREACH/DISTINCT/ORDER/LIMIT/SPLIT/STORE, ít nhất 4 hàm (SUM, COUNT, AVG, MAX…).

**Phụ trách:** thành viên C (xem [phân công](../../README.md#phân-công-mỗi-người-20)). Quy ước chung: [`docs/quy-uoc.md`](../../docs/quy-uoc.md).

**Bài viết:** mục 1.4.2, 2.4.1, 3.5.1, 4.1.1, 4.1.3 và Phụ lục B (`report/sections/14c-*`, `24a-*`, `35-*`, `41-*`, `96c-*`).

**Chạy (trong `ssh may1`, thư mục `~/src`):**

```bash
bash cau04_pig/run.sh     # pig -x mapreduce -f cau04.pig tren YARN, chep ket qua nho ve output/ (~6 phut)
bash cau04_pig/test.sh    # pig -x local tren du lieu mau + kiem tra output/ (~15 giay)
```

- **Cách hiểu đề:** "bảng sự kiện" là bảng sự kiện đơn hàng `orders` (`fact_main`). Bảng này JOIN (`USING 'replicated'`) với `customers` và `products`. Sự kiện JSON không có `customer_id`/`product_id`, nên chỉ được LOAD bằng `JsonLoader` rồi JOIN với đơn theo mã đơn để kiểm tra nhất quán, không cộng vào doanh thu.
- **Đọc:** bản chụp `/btl/raw/*/ingest_date=2026-08-01/` (`run.sh` gọi `../cau03_hdfs/init_zones.sh` nếu chưa có).
- **Ghi:** `/btl/staging/orders/` (vùng staging), `/btl/output/cau04_pig/{segment_stats,category_summary,top10_products,compare_category_month,event_check,checks,rejected_orders}/`.
- **Tham số:** `-param SNAP=… RAW=… STAGING=… OUT=… PAR=…`, mặc định như trên, `PAR=1`.

## Vùng staging `/btl/staging/orders`

- 14.408 đơn sạch (bỏ OUTLIER/DUPLICATE/LATE, giữ MISSING).
- Định dạng TSV: không tiêu đề, không BOM, xuống dòng LF.
- 24 cột: 23 cột gốc theo đúng thứ tự cũ, `timestamp` đổi tên thành `order_ts`, thêm cột cuối `order_month` (`YYYY-MM`).
- Tên và kiểu cột nằm trong `.pig_header` / `.pig_schema` cùng thư mục.
- `review_score` trống được ghi là ô rỗng (NULL), không thay bằng 0.
- `campaign_id` trống được ghi là `NONE`.
- `delivery_days` là số nguyên.

## Tệp

| Tệp | Nội dung |
|---|---|
| `cau04.pig` | Kịch bản chính (LOAD, FILTER, SPLIT, FOREACH, JOIN, GROUP, DISTINCT, ORDER, LIMIT, UNION, STORE) |
| `run.sh` | Chạy trên cụm, đo thời gian, chép kết quả về `output/` |
| `job_timeline.py` | Lấy thời gian chờ và thời gian chạy của từng job từ JobHistory REST API |
| `test.sh` | TC1–TC4 chạy `pig -x local` trên `tests/fixtures/` (tự thêm BOM, CRLF); TC5–TC6 kiểm tra `output/` (tổng khớp Câu 1, trùng với MapReduce) |
| `output/compare_category_month.csv` | Tệp đối chiếu theo quy ước §3, **giống hệt** tệp của Câu 5 |
| `output/checks.tsv` | Số bản ghi qua từng bước: HEADER, INVALID, từng `quality_flag`, DISTINCT, JOIN |
| `output/segment_stats.tsv`, `category_summary.tsv`, `top10_products.tsv`, `event_check.tsv` | Kết quả phân tích |
| `output/staging_before_after.txt` | Ví dụ dòng trước/sau làm sạch, dung lượng raw và staging |
| `output/describe.txt` | Kết quả `DESCRIBE` (schema của `orders_raw`, `events`, `enriched`) |
| `output/pig_job_stats.txt`, `pig_job_timeline.tsv`, `runtime.txt`, `version_history.txt` | Thống kê job do Pig in ra, thời gian chạy |

## Số liệu chính (lần chạy 2026-10-11)

- 15.001 dòng đọc vào → 1 tiêu đề, 0 không hợp lệ → SPLIT giữ 14.408, loại 592 → JOIN 14.408, lệch danh mục 0.
- DISTINCT trên 20 cột nội dung: 15.000 → 15.000, tức DUPLICATE không trùng nội dung.
- 5.000/5.000 sự kiện khớp với đơn gốc; 321 sự kiện thuộc đơn bị loại.
- Pig sinh 17 job MapReduce, chạy hết 339,1 s. Các job chạy thật tổng cộng 129,0 s; phần còn lại là chờ YARN, vì cụm đang chạy chung job Spark của Câu 6.
