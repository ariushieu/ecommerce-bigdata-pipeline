# Câu 4 – Pig Latin

**Yêu cầu:** LOAD + schema, FILTER, JOIN sự kiện với 2 bảng danh mục, GROUP theo category × customer_segment, FOREACH/DISTINCT/ORDER/LIMIT/SPLIT/STORE, ít nhất 4 hàm (SUM, COUNT, AVG, MAX…).

**Phụ trách:** _(chưa phân công)_

**Chạy (trong `ssh may1`, thư mục `~/src`):**

```bash
pig -x mapreduce -f cau04_pig/<file>.pig
```

## Quy ước
- Mã nguồn để ngay trong thư mục này; kết quả nhỏ (CSV tổng hợp, ảnh chụp) để trong `output/`.
- Đường dẫn HDFS dùng chung: xem `src/cau03_hdfs/README.md` (do người làm Câu 3 chốt).
- Áp dụng **quy tắc làm sạch chung**: bỏ `quality_flag` ∈ {OUTLIER, DUPLICATE, LATE}, giữ MISSING.
- Nếu có kiểm thử tự động, viết `test.sh` (chạy được trong may1). CI sẽ tự chạy mọi `src/*/test.sh`.
