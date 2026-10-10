# Câu 2 – Thu thập dữ liệu bằng Flume

**Yêu cầu:** Hai kịch bản Flume: (i) nạp CSV theo lô vào HDFS; (ii) nhận `order_event` qua HTTP/Netcat vào HDFS hoặc HBase. Giải thích Memory/FileChannel và cơ chế chống mất dữ liệu.

**Phụ trách:** _(chưa phân công)_

**Chạy (trong `ssh may1`, thư mục `~/src`):**

```bash
flume-ng agent -n a1 -c $FLUME_HOME/conf -f cau02_flume/<file>.conf
```

## Quy ước
- Mã nguồn để ngay trong thư mục này; kết quả nhỏ (CSV tổng hợp, ảnh chụp) để trong `output/`.
- Đường dẫn HDFS dùng chung: xem `src/cau03_hdfs/README.md` (do người làm Câu 3 chốt).
- Áp dụng **quy tắc làm sạch chung**: bỏ `quality_flag` ∈ {OUTLIER, DUPLICATE, LATE}, giữ MISSING.
- Nếu có kiểm thử tự động, viết `test.sh` (chạy được trong may1). CI sẽ tự chạy mọi `src/*/test.sh`.
