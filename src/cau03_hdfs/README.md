# Câu 3 – Vùng dữ liệu HDFS

**Yêu cầu:** Thiết kế raw/staging/curated/output, phân vùng theo thời gian và category, tính dung lượng khi nhân bản 3 lần, vai trò NameNode/DataNode/YARN, phương án khôi phục khi hỏng một node.

**Bài viết:** mục 3.2.1 và 3.3 của báo cáo – [`report/sections/32a-hdfs.md`, `33-pipeline.md`](../../report/sections/).

**Phụ trách:** thành viên B (xem [phân công](../../README.md#phân-công-mỗi-người-20)). Quy ước chung: [`docs/quy-uoc.md`](../../docs/quy-uoc.md).

## Vùng dữ liệu (đường dẫn chốt cho cả nhóm)

| Vùng | Đường dẫn | Định dạng | Ai ghi | Ai đọc | Lưu giữ đề xuất |
|---|---|---|---|---|---|
| raw | `/btl/raw/<bảng>/ingest_date=YYYY-MM-DD/` | Nguyên bản: CSV (còn BOM, tiêu đề), JSON Lines | `init_zones.sh` (bản chụp `2026-08-01`), Flume (Câu 2) | Pig, MapReduce, Spark, HBase loader | 1 năm nhân bản 3, sau đó lưu trữ lạnh |
| staging | `/btl/staging/<bảng>/` | TSV đã làm sạch, không BOM, không tiêu đề | Pig (Câu 4) | Pig, Hive/Spark nếu cần | 30 ngày (tạo lại được từ raw) |
| curated | `/btl/curated/orders/year=YYYY/month=MM/category=<cat>/` | Parquet nén Snappy | Spark (Câu 6) | Spark SQL, BigSheets, R | Lâu dài |
| output | `/btl/output/cau04_pig/`, `cau05_mr/`, `cau06_spark/` | CSV/Parquet tổng hợp nhỏ | từng câu | Dashboard, báo cáo | Ghi đè mỗi lần chạy |
| backup | `/btl/backup/hbase/` | Snapshot HBase (ExportSnapshot) | Câu 7 | Khôi phục HBase | Theo chính sách sao lưu |

## Chạy (trong `ssh may1`, thư mục `~/src`)

```bash
bash cau03_hdfs/init_zones.sh            # tạo 4 vùng + nạp bản chụp 2026-08-01 (không ghi đè; --force để nạp lại)
bash cau03_hdfs/zones_report.sh          # số liệu thật: du, count, fsck, dfsadmin, YARN, HBase, fetchImage -> output/zones_report.txt
spark-submit --master 'local[2]' cau03_hdfs/parquet_probe.py   # đo tỷ lệ nén CSV/Parquet và số tệp khi phân vùng -> output/parquet_probe.txt
bash cau03_hdfs/test.sh                  # CI (~25 s)
```

Demo khôi phục khi hỏng node chạy **trên máy thật** (Git Bash), vì cần `docker stop`/`docker start`:

```bash
bash src/cau03_hdfs/recovery_demo.sh --check   # chỉ chuẩn bị tệp demo và in vị trí block, không tắt node
bash src/cau03_hdfs/recovery_demo.sh           # tắt datanode3 ~5–8 phút rồi bật lại; log -> output/recovery_demo.log
```

> Cụm dùng chung: báo cả nhóm trước khi chạy bản đầy đủ. Job đang chạy trên datanode3 sẽ bị chạy lại, HBase chuyển region sang node khác.

## Tệp

| Tệp | Nội dung |
|---|---|
| `init_zones.sh` | Tạo `/btl/{raw,staging,curated,output}` và nạp bản chụp chuẩn |
| `zones_report.sh` | Thu thập số liệu dung lượng (logic và ×3), số tệp, fsck, dfsadmin, YARN node, dung lượng HBase trên HDFS, sao lưu fsimage |
| `parquet_probe.py` | Ghi thử dữ liệu sạch dưới nhiều định dạng/kiểu phân vùng vào `/tmp/cau03_probe` (xóa khi xong), đo byte và số tệp |
| `recovery_demo.sh` | Demo khôi phục: tắt datanode3, đọc lại tệp, chờ dead, NameNode nhân bản lại, bật lại node, kiểm tra hết thiếu/thừa bản sao |
| `test.sh` | CI: vùng tồn tại, 4 tệp bản chụp đúng kích thước gốc, replication 3, HDFS HEALTHY, cấu hình (thời gian đánh dấu dead 150 s) |
| `output/zones_report.txt`, `output/parquet_probe.txt`, `output/recovery_check.log` | Kết quả đã chạy (2026-10-11) |

## Kết quả chính (2026-10-11)

| Chỉ số | Giá trị |
|---|---|
| raw / staging / curated / output (logic → ×3) | 7.224.382 → 21.673.146 / 2.308.599 → 6.925.797 / 2.352.399 → 7.057.197 / 432.547 → 1.297.641 byte |
| fsck `/btl` | 239 tệp, 227 block, block trung bình 114.988 byte, replication trung bình 3,0, 0 thiếu bản sao, HEALTHY |
| Tệp nhỏ ở curated | 115 tệp, trung bình 20.456 byte/tệp = 0,0152% một block 128 MiB |
| Tỷ lệ nén (so với raw) | orders Parquet 1 tệp 0,258; phân vùng 114 tệp 0,604; phân vùng 12 task 1.368 tệp 3,885; events Parquet 0,100 |
| HBase `btl:order_events` | 5.000 sự kiện = 388.094 byte (×3 = 1.164.282) |
| Đánh dấu DataNode dead | 2 × 60 s + 10 × 3 s = 150 s (mặc định 630 s) |
| fsimage (fetchImage) | 37.095 byte |
