# PHỤ LỤC

## Phụ lục A. Hướng dẫn cài đặt và chạy chương trình

**Yêu cầu:** máy tính từ 16 GB RAM, Docker Desktop (cấp cho Docker ít nhất 10 GB RAM) và Git. Không cần cài Hadoop, Spark, Python hay R lên máy, vì mọi công cụ đều chạy trong container.

**Bước 1 – Lấy mã nguồn và dựng cụm** (PowerShell hoặc Git Bash, trên máy thật):

```bash
git clone https://github.com/ariushieu/ecommerce-bigdata-pipeline.git
cd ecommerce-bigdata-pipeline
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1   # Git Bash/Linux: bash scripts/setup.sh
docker compose pull          # tải image dựng sẵn từ GitHub Container Registry
docker compose up -d         # bật 5 container: masternode, datanode1-3, rstudio
```

**Bước 2 – Bật dịch vụ và kiểm tra** (trong `ssh may1`):

```bash
start-cluster.sh             # lần đầu sẽ format HDFS; bật HDFS, YARN, HBase, history server
smoke-test.sh                # phải ra 8 PASS
cd ~/src && bash cau03_hdfs/init_zones.sh    # tạo 4 vùng, nạp bản chụp chuẩn vào /btl/raw
```

**Bước 3 – Chạy từng câu** (trong `ssh may1`, thư mục `~/src`; Câu 8, 9 và Câu 3 phần demo chạy trên máy thật):

*[Bảng:pl-lenh-chay]. Lệnh tái lập kết quả từng câu*

| Câu | Lệnh | Thời gian (khoảng) | Kết quả chính |
|---|---|---|---|
| 1 | `cd cau01_5v && python3 profile_data.py` | 5 s | `output/profile.md` |
| 2 | `bash cau02_flume/run_batch.sh`; `bash cau02_flume/run_stream.sh`; `bash cau02_flume/crash_demo.sh` | 1 + 1 + 2 phút | `/btl/raw/*/ingest_date=<hôm nay>`, bảng `btl:order_events` |
| 3 | `bash cau03_hdfs/zones_report.sh`; máy thật: `bash src/cau03_hdfs/recovery_demo.sh` | 30 s; 6–8 phút | `output/zones_report.txt`, `output/recovery_demo.log` |
| 4 | `bash cau04_pig/run.sh` | 5–6 phút | `/btl/staging/orders`, `/btl/output/cau04_pig` |
| 5 | `bash cau05_mapreduce/run.sh`; `bash cau05_mapreduce/bench.sh 3` | 1 phút; 2 phút | `/btl/output/cau05_mr` |
| 6 | `bash cau06_spark/run.sh` (thêm `--bench` để đo hiệu năng) | 1 phút (bench 15 phút) | `/btl/curated/orders`, `/btl/output/cau06_spark` |
| 7 | `bash cau07_hbase/run.sh` | 2 phút | bảng `btl:customer_orders`, snapshot |
| 8 | máy thật: `bash src/cau08_bigsheets/chay.sh` | 1 phút | `docs/images/cau08-*.png` |
| 9 | máy thật: `bash src/cau09_r/chay.sh` | 1 phút | `docs/images/cau09-*.png`, CSDL kết quả |
| 10 | `cd cau10_doi_chieu && python3 compare.py && bash bench.sh 3` | 10 giây; 15 phút | `output/doi_chieu.md`, `output/bench.tsv` |

**Nhận xét [Bảng:pl-lenh-chay]:** các câu 4, 5, 6 cần dữ liệu ở vùng raw (Bước 2). Câu 6 và Câu 10 dùng lại hàm làm sạch của Câu 6, Câu 10 dùng lại job MapReduce của Câu 5. Các câu còn lại chạy độc lập.

**Bước 4 – Kiểm thử:** mỗi thư mục câu có `test.sh`, ví dụ `cd ~/src/cau05_mapreduce && bash test.sh`. GitHub Actions tự chạy toàn bộ các `test.sh` này trên một cụm mới ở mỗi lần cập nhật mã nguồn (workflow "Cluster").

**Bước 5 – Ghép báo cáo** (máy thật): `bash scripts/build-report.sh`, kết quả ở `report/build/BaoCao.docx`.

**Giao diện web:** HDFS `localhost:9870`, YARN `localhost:8088`, JobHistory `localhost:19888`, Spark History `localhost:18080`, HBase `localhost:16010`, RStudio `localhost:8787`.

**Tắt cụm an toàn:** `docker compose stop`. Container tự tắt HBase → YARN → HDFS đúng thứ tự. Không dùng `docker kill`.
