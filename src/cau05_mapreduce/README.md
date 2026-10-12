# Câu 5 – MapReduce (Java)

**Yêu cầu:** Doanh thu và tỷ lệ trả hàng theo danh mục × tỉnh × tháng. Mapper, Reducer, Combiner, Partitioner tự viết; ít nhất 3 test case.

**Phụ trách:** thành viên C (xem [phân công](../../README.md#phân-công-mỗi-người-20)). Quy ước chung: [`docs/quy-uoc.md`](../../docs/quy-uoc.md).

**Bài viết:** mục 1.4.2, 3.5.2, 4.1.2, 4.1.3 và Phụ lục B (`report/sections/14c-*`, `35-*`, `41-*`, `96c-*`).

**Chạy (trong `ssh may1`, thư mục `~/src`):**

```bash
bash cau05_mapreduce/run.sh     # build + 3 job tren YARN, chep ket qua ve output/ (~1 phut)
bash cau05_mapreduce/bench.sh   # do thoi gian co/khong Combiner, 3 lan -> output/bench.tsv
bash cau05_mapreduce/test.sh    # 5 kiem thu o che do local (~20 giay)

# chay tay mot job:
bash cau05_mapreduce/build.sh
hadoop jar cau05_mapreduce/build/cau05.jar btl.cau05.RevenueReturnJob \
  [-D cau05.level=category_month] [-D cau05.combiner=false] [-D cau05.reducers=3] \
  /btl/raw/orders/ingest_date=2026-08-01/orders.csv /btl/output/cau05_mr/category_province_month
```

- **Vào:** `/btl/raw/orders/ingest_date=2026-08-01/orders.csv`, tệp gốc còn BOM, tiêu đề và CRLF.
- **Ra:**
  - `/btl/output/cau05_mr/category_province_month/`: TSV `category, province, month, orders, net_revenue, returned, return_rate_pct`; `province` là tỉnh giao hàng.
  - `…/category_province_month_nocombiner/`: cùng kết quả, chạy không Combiner.
  - `…/category_month/`: dùng để sinh `compare_category_month.csv`.

## Thiết kế

| Thành phần | Kiểu vào → ra | Ghi chú |
|---|---|---|
| `RevenueMapper` | (LongWritable, Text) → (Text `cat⇥prov⇥month`, `OrderStats`) | Bỏ BOM, tiêu đề, dòng hỏng; bỏ OUTLIER/DUPLICATE/LATE, giữ MISSING; tiền đổi sang xu bằng `BigDecimal`; đếm bằng Counter `DataQuality` |
| `OrderStats` (Writable) | (orders, revenueCents, returned) | Ba tổng cộng được → Combiner hợp lệ |
| `StatsCombiner` | (Text, OrderStats*) → (Text, OrderStats) | Chỉ cộng, không chia |
| `CategoryPartitioner` | category → reducer | Beauty, Books → 0; Electronics, Fashion → 1; Home, Sports → 2; nối `part-r-*` được thứ tự toàn cục |
| `RateReducer` | (Text, OrderStats*) → (Text, Text) | Tỷ lệ × 100 = (20000·r + n) div (2n), làm tròn HALF_UP bằng số nguyên |

Khóa là `Text` nối bằng tab. Tab nhỏ hơn mọi ký tự in được, nên thứ tự byte trùng với thứ tự (danh mục, tỉnh, tháng).

## Tệp

| Tệp | Nội dung |
|---|---|
| `java/btl/cau05/*.java` | Mã nguồn; `build.sh` biên dịch thành `build/cau05.jar` (không đưa lên Git) |
| `run.sh`, `bench.sh`, `summarize.sh`, `partition_balance.py` | Chạy trên cụm, đo thời gian, tóm tắt, so sánh 3 cách chia reducer |
| `test.sh`, `tests/` | TC1 làm sạch (Counter), TC2 Combiner bật/tắt, TC3 Partitioner, TC4 gộp và làm tròn, TC5 `output/` so với oracle Python `tests/oracle.py` |
| `output/category_province_month.tsv` | Kết quả chính (2.049 dòng) |
| `output/compare_category_month.csv` | Tệp đối chiếu theo quy ước §3, **giống hệt** tệp của Câu 4 |
| `output/counters_*.txt`, `runtime.txt`, `bench.tsv` | Toàn bộ counter và thời gian của từng job |
| `output/partitions.txt`, `partition_balance.txt`, `province_summary.tsv`, `cell_stats.txt` | Tải reducer, gộp theo tỉnh, phân bố ô |

## Số liệu chính (lần chạy 2026-10-11)

- Map vào 15.001 dòng, ra 14.408 cặp. Counter: tiêu đề 1, OUTLIER 297, DUPLICATE 149, LATE 146, OK 14.095, MISSING 313.
- Combiner giảm số bản ghi qua shuffle từ 14.408 xuống 2.049 và số byte shuffle từ 742.292 xuống 105.658 (−85,8%). Số bản ghi tràn đĩa giảm từ 28.816 xuống 4.098.
- Thời gian trung bình 3 lần: 14,6 s khi bật Combiner, 16,2 s khi tắt.
- Tổng 14.408 đơn, doanh thu 78.218.341,22, 1.114 đơn trả, khớp Câu 1.
