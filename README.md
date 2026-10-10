# ecommerce-bigdata-pipeline

[![CI](https://github.com/ariushieu/ecommerce-bigdata-pipeline/actions/workflows/ci.yml/badge.svg)](https://github.com/ariushieu/ecommerce-bigdata-pipeline/actions/workflows/ci.yml)
[![Cluster](https://github.com/ariushieu/ecommerce-bigdata-pipeline/actions/workflows/cluster.yml/badge.svg)](https://github.com/ariushieu/ecommerce-bigdata-pipeline/actions/workflows/cluster.yml)

Bài tập lớn học phần **Xử lý dữ liệu lớn (CTKU122)** – HUNRE, lớp ĐH13C.
**Đề 01: Phân tích hành vi mua sắm và vận hành thương mại điện tử.** Mục tiêu: tối ưu doanh thu, tỷ lệ hoàn trả và thời gian giao hàng ([đề bài đầy đủ](docs/de-bai.md)).

Toàn bộ chạy trên một cụm Hadoop 4 máy dựng bằng Docker. Không cần cài Hadoop, Spark, R… lên máy thật.

| Công cụ | Phiên bản | Câu |
|---|---|---|
| Flume | 1.11.0 | 2 |
| HDFS · YARN · MapReduce (Java) | Hadoop 3.2.2 | 3, 5 |
| Pig | 0.17.0 | 4 |
| Spark (PySpark) | 3.1.2 | 6 |
| HBase | 2.5.16 | 7 |
| R · tidyverse · RSQLite | 4.4 | 9 |

## Cấu trúc thư mục

```
├── README.md
├── docker-compose.yml        cụm 4 máy Hadoop + 1 máy RStudio
├── setup.ps1 · setup.sh      cài đặt một lần cho mỗi thành viên
├── mo-terminal.cmd           mở 4 terminal: may1 (masternode) … may4 (datanode3)
├── data/                     dữ liệu đề bài (chỉ đọc trong container)
├── docs/                     đề bài, hướng dẫn môi trường, ảnh chụp
├── infra/                    Dockerfile, cấu hình Hadoop/Spark/HBase/Flume, script vận hành cụm
├── src/
│   ├── cau02_flume/          thu thập dữ liệu
│   ├── cau03_hdfs/           vùng dữ liệu HDFS
│   ├── cau04_pig/            Pig Latin
│   ├── cau05_mapreduce/      MapReduce (Java)
│   ├── cau06_spark/          PySpark
│   ├── cau07_hbase/          HBase
│   ├── cau08_bigsheets/      mô phỏng BigSheets + dashboard
│   └── cau09_r/              R + SQLite
└── report/                   Câu 1 + Câu 10 (báo cáo tổng hợp)
```

## Bắt đầu (mỗi thành viên làm một lần)

Cần: **Docker Desktop**, **Git**, máy **từ 16 GB RAM** (Docker được cấp ≥ 10 GB).

```powershell
git clone https://github.com/ariushieu/ecommerce-bigdata-pipeline.git
cd ecommerce-bigdata-pipeline
powershell -ExecutionPolicy Bypass -File .\setup.ps1   # sinh khóa SSH, thêm may1..may4 vào ~/.ssh/config
docker compose pull                                    # tải image dựng sẵn
docker compose up -d                                   # bật cụm
.\mo-terminal.cmd                                      # mở 4 terminal
```

Trong terminal **may1**:

```bash
start-cluster.sh     # bật HDFS, YARN, Spark History, HBase (lần đầu sẽ format HDFS)
smoke-test.sh        # kiểm tra mọi công cụ, phải ra 8 PASS
```

Chi tiết (giao diện web, tắt máy an toàn, xử lý lỗi): **[docs/moi-truong.md](docs/moi-truong.md)**.

## Quy ước làm việc nhóm

1. **Nhánh:** mỗi người làm trên nhánh riêng `cauXX-ten` (ví dụ `cau05-minh`), tạo Pull Request vào `main`. CI phải xanh mới merge.
2. **Thư mục:** chỉ sửa trong `src/cauXX_*` của mình. Muốn sửa `infra/` hay `docker-compose.yml` thì báo nhóm trước.
3. **Làm sạch dữ liệu thống nhất:** bỏ bản ghi có `quality_flag` ∈ {OUTLIER, DUPLICATE, LATE}; giữ MISSING và xử lý ô trống. Pig, MapReduce, Spark và R đều áp dụng y hệt.
4. **Phép tính đối chiếu:** Pig (Câu 4), MapReduce (Câu 5) và Spark (Câu 6) cùng xuất *doanh thu và tỷ lệ trả hàng theo category × tháng*, để Câu 10 so sánh được.
5. **Kiểm thử:** nếu thư mục câu có `test.sh`, CI sẽ tự chạy nó trên cụm thật.
6. **Không commit:** khóa SSH (`ssh-key/`), bộ cài (`infra/downloads/*.tar.gz`), file build (`*.jar`, `*.class`). `.gitignore` đã chặn sẵn.

## Phân công (đề xuất)

| Thành viên | Câu | Nội dung |
|---|---|---|
| A – nhóm trưởng | 1, 10 | 5V, phân loại dữ liệu; báo cáo tổng hợp |
| B | 2, 3 | Flume; vùng dữ liệu HDFS (làm trước, cả nhóm dùng chung) |
| C | 4, 5 | Pig; MapReduce Java |
| D | 6, 7 | PySpark; HBase |
| E | 8, 9 | BigSheets + dashboard; R |

## CI/CD

| Workflow | Chạy khi | Làm gì |
|---|---|---|
| `ci.yml` | mọi push / PR | Kiểm tra script (shellcheck), Dockerfile (hadolint), `docker-compose.yml`, cú pháp Python, Java, R |
| `cluster.yml` | push / PR đụng `infra/`, `src/`, compose; chạy tay | Build image → dựng cụm 4 máy trên GitHub Actions → `smoke-test.sh` + mọi `src/*/test.sh` → nếu là `main` thì **đẩy image lên GHCR** |

Image dựng sẵn: `ghcr.io/ariushieu/ecommerce-bigdata-pipeline/btl-node` và `…/btl-r`.
