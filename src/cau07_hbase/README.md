# Câu 7 – HBase

**Yêu cầu:** Bảng truy cập ngẫu nhiên, RowKey `customer_id#reverse_timestamp`, ≥3 column families, version/timestamp, create/put/get/scan/delete, pre-split, TTL, nén, backup (snapshot), phân quyền.

**Phụ trách:** _(chưa phân công)_

**Chạy (trong `ssh may1`, thư mục `~/src`):**

```bash
hbase shell -n cau07_hbase/<file>.rb
```

## Quy ước
- Mã nguồn để ngay trong thư mục này; kết quả nhỏ (CSV tổng hợp, ảnh chụp) để trong `output/`.
- Đường dẫn HDFS dùng chung: xem `src/cau03_hdfs/README.md` (do người làm Câu 3 chốt).
- Áp dụng **quy tắc làm sạch chung**: bỏ `quality_flag` ∈ {OUTLIER, DUPLICATE, LATE}, giữ MISSING.
- Nếu có kiểm thử tự động, viết `test.sh` (chạy được trong may1). CI sẽ tự chạy mọi `src/*/test.sh`.
