# Câu 6 – Spark (PySpark)

**Yêu cầu:** DataFrame pipeline: sản phẩm tăng trưởng nhanh và khách hàng có nguy cơ rời bỏ. Đọc CSV/JSON, làm sạch, join, ≥5 transformations, ≥3 actions, cache/persist, xuất CSV/Parquet, so sánh với MapReduce.

**Phụ trách:** _(chưa phân công)_

**Chạy (trong `ssh may1`, thư mục `~/src`):**

```bash
spark-submit cau06_spark/<file>.py
```

## Quy ước
- Mã nguồn để ngay trong thư mục này; kết quả nhỏ (CSV tổng hợp, ảnh chụp) để trong `output/`.
- Đường dẫn HDFS dùng chung: xem `src/cau03_hdfs/README.md` (do người làm Câu 3 chốt).
- Áp dụng **quy tắc làm sạch chung**: bỏ `quality_flag` ∈ {OUTLIER, DUPLICATE, LATE}, giữ MISSING.
- Nếu có kiểm thử tự động, viết `test.sh` (chạy được trong may1). CI sẽ tự chạy mọi `src/*/test.sh`.
