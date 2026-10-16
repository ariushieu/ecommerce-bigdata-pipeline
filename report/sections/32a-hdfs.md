### 3.2.1. Vùng dữ liệu trên HDFS

#### a) Thiết kế bốn vùng dữ liệu

Dữ liệu chia thành bốn vùng theo mức độ xử lý; mỗi vùng có một chủ ghi duy nhất nên các thành viên làm song song mà không ghi đè nhau.

*[Bảng:c03-vung-du-lieu]. Bốn vùng dữ liệu trên HDFS*

| Vùng | Đường dẫn | Định dạng | Ai ghi |
|---|---|---|---|
| raw | `/btl/raw/<bảng>/ingest_date=YYYY-MM-DD/` | Nguyên văn CSV, JSON Lines | `init_zones.sh`, Flume |
| staging | `/btl/staging/<bảng>/` | Đã làm sạch, tách bằng tab | Pig (Câu 4) |
| curated | `/btl/curated/orders/year=YYYY/month=MM/category=<cat>/` | Parquet Snappy | Spark (Câu 6) |
| output | `/btl/output/cau04_pig/`, `cau05_mr/`, `cau06_spark/` | Bảng tổng hợp nhỏ | Từng câu |

**Nhận xét [Bảng:c03-vung-du-lieu]:**
- **Raw phân vùng theo ngày nạp:** dữ liệu đến muộn hay sai thứ tự (50,27% cặp sự kiện liên tiếp, mục 1.3.2) vào partition của ngày nhận, partition cũ không phải sửa. Bản chụp `ingest_date=2026-08-01` là đầu vào chung của Pig, MapReduce, Spark.
- **Curated phân vùng theo tháng × danh mục** nên Spark chỉ đọc thư mục cần (*partition pruning*). Ở quy mô 100.000 đơn/ngày, mỗi partition khoảng 19,8 MB; chia tới ngày chỉ còn khoảng 0,66 MB, sinh nhiều tệp nhỏ. Cây thư mục thực tế ở Phụ lục B (B.7).

#### b) Dung lượng thực tế và dự báo khi nhân bản 3 lần

*[Bảng:c03-dung-luong-thuc-te]. Dung lượng các vùng trên cụm (`hdfs dfs -du -s`; 11/10/2026 23:21)*

| Vùng | Số tệp | Logic (byte) | Chiếm dụng × 3 (byte) |
|---|---:|---:|---:|
| raw | 8 | 7.224.382 | 21.673.146 |
| staging | 4 | 2.308.599 | 6.925.797 |
| curated | 115 | 2.352.399 | 7.057.197 |
| output | 61 | 446.959 | 1.340.877 |
| HBase `btl:order_events` | – | 388.094 | 1.164.282 |

**Nhận xét [Bảng:c03-dung-luong-thuc-te]:** hệ số chiếm dụng đúng bằng 3, kể cả HBase; `hdfs fsck /btl` báo 191 block, 0 block thiếu bản sao, HEALTHY. Tệp lớn nhất chỉ dùng 0,67% một block, nên vấn đề thực tế là tệp nhỏ (mỗi tệp, block chiếm khoảng 150 byte RAM NameNode [TL:white2015]).

Đo trên `orders` và `events`, Parquet Snappy một tệp còn 0,258 và 0,100 lần raw; ghi phân vùng mà không gom theo khóa thì gấp 3,885 lần, nên Câu 6 gọi `repartition(year, month, category)` trước `partitionBy` ([Bảng:c03-dinh-dang], Phụ lục B). Dự báo dưới đây dùng giả định mục 1.3.1: raw `orders` 5,6 GB/năm, raw `events` 163,3 GB/năm.

*[Bảng:c03-du-bao-dung-luong]. Dự báo dung lượng HDFS năm đầu tiên (GB)*

| Vùng | Cách tính | Logic | × 3 bản sao |
|---|---|---:|---:|
| raw (giữ 1 năm) | 5,6 + 163,3 | 168,9 | **506,7** |
| staging (giữ 30 ngày) | orders × 1,004 × 30/365 | 0,46 | 1,4 |
| curated `orders` / `events` | × 0,258 / × 0,100 | 1,45 / 16,25 | 4,3 / 48,8 |
| output | Giả định ≤ 1 GB | ≤ 1 | ≤ 3 |
| HBase (TTL 180 ngày) | 2.000.000 sự kiện/ngày × 77,6 byte × 180 | 27,9 | 83,8 |
| **Cộng** | | **≈ 216** | **≈ 648** |

**Nhận xét [Bảng:c03-du-bao-dung-luong]:** raw chiếm 78%; giữ mức sử dụng dưới khoảng 70% thì năm đầu cần khoảng **0,93 TB**. Dùng *erasure coding* `XOR-2-1-1024k` cho raw sau 90 ngày [TL:hdfs-ec] thì raw còn khoảng **315,8 GB/năm** (tiết kiệm 38%), đổi lại đọc chậm hơn và chỉ chịu hỏng 1 node.

#### c) Vai trò của NameNode, DataNode và YARN

*[Bảng:c03-vai-tro]. Vai trò các tiến trình HDFS và YARN trong cụm*

| Tiến trình (máy) | Vai trò |
|---|---|
| NameNode (masternode) | Giữ không gian tên và bản đồ block trong RAM, ghi *edit log*, quyết định nơi đặt bản sao |
| SecondaryNameNode (masternode) | Gộp fsimage và edit log mỗi giờ; **không phải** NameNode dự phòng |
| DataNode (datanode1–3) | Lưu block, heartbeat 3 s/lần; bị coi là chết sau **150 s** (mặc định 630 s) |
| ResourceManager (masternode) | Cấp container, khởi động ApplicationMaster của mỗi job |
| NodeManager (datanode1–3) | Chạy container và shuffle MapReduce |

**Nhận xét [Bảng:c03-vai-tro]:** DataNode và NodeManager chung máy nên YARN chạy task trên node giữ block (*data locality*) [TL:vavilapalli2013]. Với 3 DataNode và hệ số 3, mỗi node giữ bản sao của mọi block; **NameNode là điểm hỏng duy nhất** [TL:shvachko2010].

#### d) Phương án khôi phục khi một node hỏng

Khi DataNode hỏng, client đọc ngay bản sao khác; sau 150 s NameNode chép lại các block thiếu nếu còn node chưa giữ block đó. Các sự cố khác xem [Bảng:c03-khoi-phuc] (Phụ lục B). Triển khai thật nên dùng NameNode HA với Quorum Journal Manager [TL:hdfs-ha], tối thiểu 4 DataNode và rack awareness.

Demo `recovery_demo.sh` (Phụ lục B.6) tắt rồi bật lại datanode3, dùng thêm một tệp hệ số 2 (9 block).

*[Bảng:c03-demo-khoi-phuc]. Diễn biến khi tắt datanode3 (mốc tính từ lúc tắt node)*

| Mốc | Thời điểm | Trạng thái quan sát được |
|---|---:|---|
| Tắt datanode3 | 0 s | Đọc lại ngay hai tệp demo: md5 khớp tệp gốc |
| NameNode loại datanode3 | 164 s | 2 sống, 1 chết; `fsck /btl`: 192/192 block thiếu bản sao, vẫn **HEALTHY** (0 block mất) |
| Tệp hệ số 2 đủ bản sao | 170 s | 9 block lại đủ 2 bản sao trên datanode1, datanode2 |
| Bật lại datanode3 | 179 s | Bật lại DataNode, NodeManager, RegionServer |
| HDFS trở lại bình thường | 196 s | `fsck /btl`: 0 block thiếu bản sao, hệ số trung bình 3,0 |

**Nhận xét [Bảng:c03-demo-khoi-phuc]:** không mất dữ liệu, không gián đoạn đọc; dữ liệu hệ số 3 chỉ còn 2 bản sao tới khi node quay lại, nên cụm thật cần ít nhất 4 DataNode. Lần chạy đầu, HMaster tự hủy vì `replace-datanode-on-failure.policy = NEVER` chỉ đặt trong `hdfs-site.xml`; thêm vào `hbase-site.xml` thì HBase hoạt động suốt quá trình.
