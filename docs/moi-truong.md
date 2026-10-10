# Môi trường Docker của BTL

Cụm 4 "máy ảo" Hadoop và 1 máy R, dựng bằng Docker.

## 1. Kiến trúc

```
                    btl-hadoop-net (172.28.0.0/16)
┌──────────────────────────────┐
│ masternode   172.28.1.1      │  NameNode · SecondaryNameNode · ResourceManager
│ (ssh may1)                   │  JobHistory · Spark History · ZooKeeper · HMaster
│                              │  + client: hdfs, yarn, spark-submit, pig, flume-ng, hbase shell
├──────────────────────────────┤
│ datanode1    172.28.1.2      │  DataNode · NodeManager · HRegionServer   (ssh may2)
│ datanode2    172.28.1.3      │  DataNode · NodeManager · HRegionServer   (ssh may3)
│ datanode3    172.28.1.4      │  DataNode · NodeManager · HRegionServer   (ssh may4)
├──────────────────────────────┤
│ rstudio      172.28.1.10     │  R 4.4 · RStudio Server · tidyverse · DBI/RSQLite
└──────────────────────────────┘
```

| Thành phần | Phiên bản | Dùng cho |
|---|---|---|
| Hadoop (HDFS, YARN, MapReduce) | 3.2.2 | Câu 3, 5 |
| Spark (+ PySpark, Python 3.8) | 3.1.2 | Câu 6 |
| Pig | 0.17.0 | Câu 4 |
| Flume | 1.11.0 | Câu 2 |
| HBase (+ ZooKeeper) | 2.5.16 | Câu 7 |
| R + tidyverse + RSQLite | 4.4 | Câu 9 |
| JDK 8 (+ Scala 2.12, sbt 1.9) | 1.8 | biên dịch MapReduce Java |

Cấu hình đáng chú ý:
- `dfs.replication = 3`, đúng yêu cầu "nhân bản 3 lần" của Câu 3.
- DataNode bị coi là "dead" sau khoảng 2,5 phút (mặc định 10,5 phút), để kịp demo khôi phục khi hỏng node.
- HBase bật nén SNAPPY/LZ4/ZSTD (thư viện Java, không cần native), bật ACL (`grant`/`revoke`) và snapshot. Phục vụ Câu 7.

## 2. Thư mục hạ tầng

```
docker-compose.yml        5 container (gốc repo)
setup.ps1 · setup.sh      cài đặt một lần: sinh khóa SSH, thêm may1..may4 vào ~/.ssh/config
mo-terminal.cmd           mở 4 terminal, mỗi máy một tab
ssh-key/                  khóa SSH riêng của máy bạn (setup sinh ra, KHÔNG đưa lên Git)
infra/
├── docker/
│   ├── node/             Dockerfile + entrypoint + lời chào cho 4 máy Hadoop (dùng chung 1 image)
│   ├── r/                Dockerfile máy R
│   └── config/           cấu hình hadoop/ spark/ hbase/ flume/
├── scripts/              start-cluster.sh, stop-cluster.sh, status.sh, smoke-test.sh, hbase-reset.sh
└── downloads/            fetch.sh (bộ cài tải về để build; file nén KHÔNG đưa lên Git)
```

Thư mục được gắn vào container:

| Trên máy thật | masternode | rstudio | Quyền |
|---|---|---|---|
| `data/` | `/data` | `/data` | **chỉ đọc**, để dữ liệu đề bài không bị sửa nhầm |
| `src/` | `/home/hadoop/src` | `/home/rstudio/src` | đọc/ghi, sửa trên máy thật là thấy ngay trong container |
| `ssh-key/` | `/ssh-key` (cả 4 máy Hadoop) | — | chỉ đọc |

> Câu 9 phải ghi bảng kết quả vào SQLite. Hãy copy `project_data.sqlite` vào `src/cau09_r/` rồi ghi vào bản copy đó.

## 3. Chạy lần đầu

```powershell
git clone https://github.com/ariushieu/ecommerce-bigdata-pipeline.git
cd ecommerce-bigdata-pipeline
powershell -ExecutionPolicy Bypass -File .\setup.ps1    # Linux/macOS/Git Bash: bash setup.sh
docker compose pull              # tải image dựng sẵn từ GHCR
docker compose up -d             # bật 5 container
ssh may1                         # vào masternode, rồi:
start-cluster.sh                 #   format HDFS (lần đầu), bật toàn bộ dịch vụ
smoke-test.sh                    #   kiểm tra mọi công cụ, phải ra 8 PASS
```

Tự build image thay vì tải (khi sửa Dockerfile hoặc cấu hình):

```bash
bash infra/downloads/fetch.sh    # tải bộ cài khoảng 1,6 GB (Pig chỉ có ở mirror chậm)
docker compose up -d --build
```

## 4. Terminal riêng cho từng máy (như Lab 05)

Nhấp đúp **`mo-terminal.cmd`**: lệnh này tự bật container nếu đang tắt, rồi mở Windows Terminal với 4 tab màu, mỗi tab là một máy. Hoặc gõ tay từ PowerShell / cmd / Git Bash:

| Lệnh | Máy | IP trong cụm | Cổng trên máy thật |
|---|---|---|---|
| `ssh may1` | masternode | 172.28.1.1 | 127.0.0.1:2201 |
| `ssh may2` | datanode1 | 172.28.1.2 | 127.0.0.1:2202 |
| `ssh may3` | datanode2 | 172.28.1.3 | 127.0.0.1:2203 |
| `ssh may4` | datanode3 | 172.28.1.4 | 127.0.0.1:2204 |

- Đăng nhập bằng user `hadoop` với khóa `ssh-key/id_ed25519`, không cần mật khẩu. `setup.ps1` ghi cấu hình vào `~/.ssh/config`, nằm giữa hai dòng `# >>> btl-cluster` và `# <<< btl-cluster`.
- Vào máy nào cũng đứng sẵn ở `~/src`, có lời chào ghi rõ vai trò máy và các tiến trình đang chạy, dấu nhắc có màu riêng (may1 đỏ, may2 xanh lá, may3 vàng, may4 xanh ngọc).
- Từ một máy SSH sang máy khác bằng tên trong cụm: `ssh datanode2`.
- Chạy lệnh một dòng cũng được: `ssh may1 status.sh`.
- Để an toàn, SSH chỉ mở trên `127.0.0.1` và chỉ đăng nhập bằng khóa. Host key cố định theo máy bạn (nằm trong `ssh-key/`) nên build lại image không bị báo lỗi đổi khóa.

## 5. Dùng hằng ngày

```bash
docker compose up -d             # bật container
ssh may1                         # rồi trong may1:
start-cluster.sh                 #   bật dịch vụ (thêm --no-hbase nếu không cần HBase)
status.sh                        #   xem tiến trình đang chạy

docker compose stop              # tắt container, dữ liệu HDFS/HBase vẫn còn
```

**Tắt máy an toàn:** khi container nhận lệnh dừng (`docker compose stop` hoặc thoát Docker Desktop), entrypoint tự tắt HBase → YARN → HDFS đúng thứ tự (masternode tắt trước, khoảng 1 phút). Tuyệt đối **không** dùng `docker kill` hay tắt nguồn đột ngột khi HBase đang chạy, vì HBase dễ hỏng (xem mục 8).

Xóa sạch để làm lại từ đầu (**mất toàn bộ dữ liệu HDFS và HBase**):
```bash
docker compose down -v
```

## 6. Giao diện web

| Dịch vụ | URL |
|---|---|
| HDFS NameNode | http://localhost:9870 |
| YARN ResourceManager | http://localhost:8088 |
| MapReduce JobHistory | http://localhost:19888 |
| Spark History | http://localhost:18080 |
| Spark job đang chạy | http://localhost:4040 |
| HBase Master | http://localhost:16010 |
| HBase RegionServer 1/2/3 | http://localhost:16030 · 16031 · 16032 |
| DataNode 1/2/3 | http://localhost:9864 · 9865 · 9866 |
| RStudio (không cần đăng nhập) | http://localhost:8787 |

Flume: masternode mở cổng **41414** (HTTP source) và **44444** (Netcat source) ra máy thật, nên có thể gửi `order_event` trực tiếp từ Windows.

## 7. Tài nguyên

Khi rảnh, cụm dùng khoảng 5 GB RAM (masternode khoảng 2,1 GB, mỗi datanode khoảng 1 GB); khi chạy job thì khoảng 7–8 GB. Docker Desktop nên được cấp tối thiểu 10 GB RAM (máy thật từ 16 GB). Máy yếu thì bật cụm bằng `start-cluster.sh --no-hbase`, hoặc tắt RStudio bằng `docker compose stop rstudio`.

## 8. Lỗi thường gặp

| Hiện tượng | Cách xử lý |
|---|---|
| Container thoát ngay, log báo `Thieu /ssh-key/...` | Chưa chạy `setup.ps1` / `setup.sh` |
| `ssh may1` báo `Connection refused` | Container chưa bật: `docker compose up -d` (hoặc chạy `mo-terminal.cmd`) |
| `ssh may1` báo `UNPROTECTED PRIVATE KEY FILE` | Chạy lại `setup.ps1` (script sẽ sửa quyền file khóa) |
| `start-cluster.sh` báo DataNode không lên sau khi `down -v` một phần | `docker compose down -v` rồi chạy lại từ đầu (clusterID lệch) |
| Script sửa trên Windows báo `\r: command not found` | Lưu file với kiểu xuống dòng **LF** (VS Code: góc dưới phải, chọn CRLF → LF). Repo đã có `.gitattributes` ép LF cho `.sh` |
| HDFS kẹt ở safe mode | Trong may1: `hdfs dfsadmin -safemode leave` |
| HBase báo `PleaseHoldException: Master is initializing` mãi không hết (thường do tắt đột ngột) | Trong may1: `hbase-reset.sh`. Lệnh này **xóa mọi bảng HBase** (dữ liệu HDFS vẫn giữ nguyên), sau đó chạy lại script tạo bảng của Câu 7 |
| Spark báo thiếu tài nguyên, job đứng ở trạng thái ACCEPTED | Tắt HBase (`stop-hbase.sh`) hoặc giảm `--num-executors` |
