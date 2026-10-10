# Câu 8 – Mô phỏng BigSheets + dashboard

**Yêu cầu:** Collection, làm sạch, calculated columns, lọc/nhóm/join, dashboard doanh thu – hoàn trả – giao hàng theo danh mục và tỉnh; hướng dẫn từng bước cho người không lập trình.

**Phụ trách:** _(chưa phân công)_

**Chạy (trong `ssh may1`, thư mục `~/src`):**

```bash
(tài liệu + ảnh chụp dashboard)
```

## Quy ước
- Mã nguồn để ngay trong thư mục này; kết quả nhỏ (CSV tổng hợp, ảnh chụp) để trong `output/`.
- Đường dẫn HDFS dùng chung: xem `src/cau03_hdfs/README.md` (do người làm Câu 3 chốt).
- Áp dụng **quy tắc làm sạch chung**: bỏ `quality_flag` ∈ {OUTLIER, DUPLICATE, LATE}, giữ MISSING.
- Nếu có kiểm thử tự động, viết `test.sh` (chạy được trong may1). CI sẽ tự chạy mọi `src/*/test.sh`.
