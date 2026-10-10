# Câu 9 – R + SQLite

**Yêu cầu:** DBI/RSQLite, SQL có JOIN + GROUP BY, dplyr/tidyr, ggplot2, hồi quy doanh thu, phân loại khả năng trả hàng, ghi kết quả lại CSDL (bản copy), đóng kết nối.

**Phụ trách:** _(chưa phân công)_

**Chạy (trong `ssh may1`, thư mục `~/src`):**

```bash
mở http://localhost:8787 → cau09_r/<file>.R
```

## Quy ước
- Mã nguồn để ngay trong thư mục này; kết quả nhỏ (CSV tổng hợp, ảnh chụp) để trong `output/`.
- Đường dẫn HDFS dùng chung: xem `src/cau03_hdfs/README.md` (do người làm Câu 3 chốt).
- Áp dụng **quy tắc làm sạch chung**: bỏ `quality_flag` ∈ {OUTLIER, DUPLICATE, LATE}, giữ MISSING.
- Nếu có kiểm thử tự động, viết `test.sh` (chạy được trong may1). CI sẽ tự chạy mọi `src/*/test.sh`.
