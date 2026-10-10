# Câu 5 – MapReduce (Java)

**Yêu cầu:** Doanh thu và tỷ lệ trả hàng theo danh mục × tỉnh × tháng. Mapper, Reducer, Combiner, Partitioner tự viết; ít nhất 3 test case.

**Phụ trách:** _(chưa phân công)_

**Chạy (trong `ssh may1`, thư mục `~/src`):**

```bash
bash cau05_mapreduce/build.sh && hadoop jar ...
```

## Quy ước
- Mã nguồn để ngay trong thư mục này; kết quả nhỏ (CSV tổng hợp, ảnh chụp) để trong `output/`.
- Đường dẫn HDFS dùng chung: xem `src/cau03_hdfs/README.md` (do người làm Câu 3 chốt).
- Áp dụng **quy tắc làm sạch chung**: bỏ `quality_flag` ∈ {OUTLIER, DUPLICATE, LATE}, giữ MISSING.
- Nếu có kiểm thử tự động, viết `test.sh` (chạy được trong may1). CI sẽ tự chạy mọi `src/*/test.sh`.
