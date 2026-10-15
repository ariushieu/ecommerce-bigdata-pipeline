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
├── scripts/                  chạy trên MÁY THẬT
│   ├── setup.ps1 · setup.sh  cài đặt một lần cho mỗi thành viên
│   └── mo-terminal.cmd       mở 4 terminal: may1 (masternode) … may4 (datanode3)
├── data/                     dữ liệu đề bài (chỉ đọc trong container)
├── docs/                     đề bài, hướng dẫn môi trường, ảnh chụp
├── infra/                    Dockerfile, cấu hình Hadoop/Spark/HBase/Flume, script chạy TRONG CỤM
├── src/
│   ├── cau01_5v/             profiling dữ liệu cho phân tích 5V
│   ├── cau02_flume/          thu thập dữ liệu
│   ├── cau03_hdfs/           vùng dữ liệu HDFS
│   ├── cau04_pig/            Pig Latin
│   ├── cau05_mapreduce/      MapReduce (Java)
│   ├── cau06_spark/          PySpark
│   ├── cau07_hbase/          HBase
│   ├── cau08_bigsheets/      mô phỏng BigSheets + dashboard
│   ├── cau09_r/              R + SQLite
│   └── cau10_doi_chieu/      đối chiếu Pig – MapReduce – Spark (Câu 10)
└── report/                   báo cáo theo mẫu CTKU122: mỗi mục một file trong sections/
```

## Bắt đầu (mỗi thành viên làm một lần)

Cần: **Docker Desktop**, **Git**, máy **từ 16 GB RAM** (Docker được cấp ≥ 10 GB).

```powershell
git clone https://github.com/ariushieu/ecommerce-bigdata-pipeline.git
cd ecommerce-bigdata-pipeline
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1   # sinh khóa SSH, thêm may1..may4 vào ~/.ssh/config
docker compose pull                                    # tải image dựng sẵn
docker compose up -d                                   # bật cụm
.\scripts\mo-terminal.cmd                              # mở 4 terminal
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

## Phân công (mỗi người 20%)

| Thành viên | Câu | Mục báo cáo phụ trách | Ngoài ra |
|---|---|---|---|
| A – Nguyễn Quốc Hiếu (nhóm trưởng) | 1, 10 | Lời mở đầu, 1.1–1.3, 2.1–2.3, 3.1, 4.5, Chương 5, Phụ lục A | Môi trường Docker/CI, ghép báo cáo |
| B – Nguyễn Trần Khánh Duy | 2, 3 | 1.4 (Flume, HDFS/YARN), 1.5, 3.2 (HDFS), 3.3 | Slide thuyết trình |
| C – Nguyễn Tiến Hiệp | 4, 5 | 1.4 (Pig, MapReduce), 2.4 (Pig), 3.5, 4.1 | |
| D – Vũ Văn Quốc | 6, 7 | 1.4 (Spark, HBase), 2.4–2.5 (Spark), 3.2 (HBase), 3.4, 3.6, 4.4 | |
| E – Phạm Văn Quyết | 8, 9 | 1.4 (BigSheets, R), 4.2, 4.3, Phụ lục C | Dashboard demo |

Mỗi câu làm **code và mục báo cáo cùng lúc**, trong cùng một Pull Request. Quy ước chung (đường dẫn HDFS, làm sạch, file đối chiếu, cách đánh số bảng/hình): [`docs/quy-uoc.md`](docs/quy-uoc.md).

## CI/CD

| Workflow | Chạy khi | Làm gì |
|---|---|---|
| `ci.yml` | mọi push / PR | Kiểm tra script (shellcheck), Dockerfile (hadolint), `docker-compose.yml`, cú pháp Python, Java, R |
| `cluster.yml` | push / PR đụng `infra/`, `src/`, compose; chạy tay | Build image → dựng cụm 4 máy trên GitHub Actions → `smoke-test.sh` + mọi `src/*/test.sh` → nếu là `main` thì **đẩy image lên GHCR** |

Image dựng sẵn: `ghcr.io/ariushieu/ecommerce-bigdata-pipeline/btl-node` và `…/btl-r`.
