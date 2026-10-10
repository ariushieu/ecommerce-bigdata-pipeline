# Câu 3 – Vùng dữ liệu HDFS

**Yêu cầu:** Thiết kế raw/staging/curated/output, phân vùng theo thời gian và category, tính dung lượng khi nhân bản 3 lần, vai trò NameNode/DataNode/YARN, demo khôi phục khi hỏng một node.

**Phụ trách:** _(chưa phân công)_

**Chạy (trong `ssh may1`, thư mục `~/src`):**

```bash
bash cau03_hdfs/<script>.sh
```

## Quy ước
- Mã nguồn để ngay trong thư mục này; kết quả nhỏ (CSV tổng hợp, ảnh chụp) để trong `output/`.
- Đường dẫn HDFS dùng chung: xem `src/cau03_hdfs/README.md` (do người làm Câu 3 chốt).
- Áp dụng **quy tắc làm sạch chung**: bỏ `quality_flag` ∈ {OUTLIER, DUPLICATE, LATE}, giữ MISSING.
- Nếu có kiểm thử tự động, viết `test.sh` (chạy được trong may1). CI sẽ tự chạy mọi `src/*/test.sh`.
