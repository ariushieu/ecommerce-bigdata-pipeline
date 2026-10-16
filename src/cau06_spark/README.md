# Câu 6 – Spark (PySpark)

**Yêu cầu:** DataFrame pipeline: sản phẩm tăng trưởng nhanh và khách hàng có nguy cơ rời bỏ. Đọc CSV/JSON, làm sạch, join, ≥5 transformations, ≥3 actions, cache/persist, xuất CSV/Parquet, so sánh với MapReduce.

**Phụ trách:** Vũ Văn Quốc – thành viên D (xem [phân công](../../README.md#phân-công-mỗi-người-20)). Quy ước chung: [`docs/quy-uoc.md`](../../docs/quy-uoc.md).

**Bài viết:** mục 1.4.3, 2.4.2, 2.5, 3.4, 3.6, 4.2.2, 4.4 và Phụ lục B (mã nguồn D) – `report/sections/14d-*.md`, `24b-*.md`, `25-*.md`, `34-*.md`, `36-*.md`, `42-*.md` (4.2.2), `44-*.md`, `96d-*.md`.

**Chạy (trong `ssh may1`, thư mục `~/src`):**

```bash
bash cau06_spark/run.sh            # spark-submit pipeline.py tren YARN (~1 phut): curated + output + output/*.csv
bash cau06_spark/run.sh --bench    # them thu nghiem hieu nang (~15 phut): bench_spark.csv, category_month_only.txt
bash cau06_spark/run.sh --cm-only  # chi do job danh muc x thang (doi chung voi 1 job MapReduce Cau 5)
bash cau06_spark/test.sh           # CI: chay lai vao thu muc tam, so voi output/ + kiem tra so lieu chinh
```

`run.sh` tự gọi `../cau03_hdfs/init_zones.sh` nên chạy được trên cụm mới.

| Tệp | Nội dung |
|---|---|
| `pipeline.py` | Đọc `/btl/raw/*/ingest_date=2026-08-01` (3 CSV + JSON Lines), làm sạch (14.408 đơn), broadcast join 2 danh mục, cờ `seen_in_stream`, `persist`, Spark SQL danh mục × tháng, tăng trưởng sản phẩm, rủi ro rời bỏ (RFM), đối chiếu sự kiện; ghi curated + output |
| `bench.py` | Cache / không cache × shuffle partitions 12 / 200 × quy mô ×1 / ×10, 3 lần mỗi cấu hình, đo I/O qua REST API Spark UI |
| `category_month_only.py` | Đúng một phép tổng hợp danh mục × tháng, để so với một job MapReduce |
| `run.sh`, `test.sh` | Chạy và kiểm thử |

**Đầu ra HDFS:**
- `/btl/curated/orders/year=YYYY/month=MM/category=<cat>/` – Parquet, 14.408 đơn, 45 cột, 114 phân vùng.
- `/btl/output/cau06_spark/` – `category_month` (CSV), `product_growth` (Parquet), `fast_growing_products` (CSV), `customer_churn` (Parquet), `churn_risk_customers` (CSV).

**Đầu ra trong `output/` (commit):**

| Tệp | Nội dung |
|---|---|
| `compare_category_month.csv` | Bảng đối chiếu Pig – MR – Spark (quy ước mục 3); trùng từng byte với Câu 4, 5 |
| `fast_growing_products.csv`, `growth_by_category.csv`, `growth_summary.csv` | 64 sản phẩm tăng nhanh; tăng trưởng theo danh mục; so với mức ngẫu nhiên |
| `churn_risk_customers.csv`, `churn_summary.csv`, `churn_by_risk.csv` | 369 khách HIGH/MEDIUM; theo phân khúc; theo mức nguy cơ × doanh thu/hoàn trả/giao hàng |
| `reconcile_events.csv` | 5.000 sự kiện khớp 5.000 đơn, 0 trường lệch |
| `pipeline_log.txt` | Bảng `show`, ví dụ trước/sau, schema, `explain`, thời gian |
| `pipeline_metrics.json`, `run_time.txt`, `hdfs_outputs.txt` | Thời gian các bước, I/O (job/stage/task/byte), lịch sử thời gian chạy, dung lượng HDFS |
| `bench_spark.csv`, `bench_spark.txt`, `bench_spark_runs.json`, `category_month_only.txt` | Thử nghiệm hiệu năng (mục 4.4) |

**Định nghĩa chính:**
- *Tăng trưởng nhanh*: ≥ 3 đơn ở cả 2 cửa sổ (P = 02–04/2026, R = 05–07/2026), doanh thu **và** số lượng tăng ≥ 50%, độ dốc 19 tháng > 0. Kèm `z_orders`, `significant` (z ≥ 1,96).
- *Rời bỏ* (mốc 31/07/2026): HIGH = không mua > 90 ngày và số đơn 6 tháng cuối < 6 tháng trước; MEDIUM = không mua > 90 ngày, hoặc > max(60, 2 × khoảng cách TB) ngày, hoặc số đơn giảm ≥ một nửa (từ ≥ 4); còn lại LOW.

**Lưu ý:** dữ liệu giả lập gần đồng đều, tín hiệu yếu: chỉ 6 sản phẩm tăng có ý nghĩa (ngẫu nhiên kỳ vọng ~10); số khách không mua 90 ngày (188) thấp hơn mức ngẫu nhiên kỳ vọng (211). Thời gian chạy dao động theo tải của cụm dùng chung (`run_time.txt`).
