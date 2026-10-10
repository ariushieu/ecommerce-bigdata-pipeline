# Đề 01 – Phân tích hành vi mua sắm và vận hành thương mại điện tử

> Học phần **CTKU122 – Xử lý dữ liệu lớn** (3 tín chỉ), lớp ĐH13C, học kỳ 1 năm học 2025–2026.
> Trích từ danh sách đề tài BTL của Bộ môn Khoa học máy tính và ứng dụng, Khoa CNTT.

Một sàn thương mại điện tử cần xây dựng nền tảng phân tích tích hợp dữ liệu đơn hàng theo lô và sự kiện mua sắm thời gian thực.

- **Công nghệ sử dụng:** Tích hợp nhiều công cụ
- **Mục tiêu phân tích:** Tối ưu doanh thu, tỷ lệ hoàn trả và thời gian giao hàng.

## Yêu cầu

| Câu | Điểm | Yêu cầu | Thư mục |
|---|---|---|---|
| 1 | 1,0 | Phân tích đặc trưng Big Data của bài toán theo tối thiểu 5V. Phân loại các tệp và trường dữ liệu thành dữ liệu có cấu trúc, bán cấu trúc và dữ liệu luồng; chỉ rõ phần nào phù hợp phân tích tĩnh và phần nào cần xử lý gần thời gian thực. | `report/` |
| 2 | 1,0 | Đề xuất kiến trúc thu thập và lưu trữ dữ liệu đầu–cuối. Thiết kế ít nhất hai kịch bản Flume: (i) nạp tệp CSV theo lô vào HDFS; (ii) nhận sự kiện `order_event` từ HTTP/Netcat/Kafka vào HDFS hoặc HBase. Viết cấu hình Source–Channel–Sink, giải thích lựa chọn MemoryChannel/FileChannel và cơ chế chống mất dữ liệu. | `src/cau02_flume/` |
| 3 | 1,0 | Thiết kế vùng dữ liệu trên HDFS gồm raw, staging, curated và output. Đề xuất cấu trúc thư mục phân vùng theo thời gian và category; tính dung lượng lưu trữ khi nhân bản 3 lần; mô tả vai trò NameNode, DataNode, YARN và phương án khôi phục khi một node hỏng. | `src/cau03_hdfs/` |
| 4 | 1,0 | Viết Pig Latin để LOAD các tệp, khai báo schema, FILTER bản ghi không hợp lệ, JOIN bảng sự kiện với hai bảng danh mục, GROUP theo category và customer_segment, sử dụng FOREACH, DISTINCT, ORDER, LIMIT, SPLIT và STORE. Bổ sung tối thiểu bốn hàm đánh giá như SUM, COUNT, AVG, MIN/MAX, SIZE, CONCAT hoặc TOKENIZE. | `src/cau04_pig/` |
| 5 | 1,0 | Xây dựng thuật toán MapReduce: tính tổng doanh thu và tỷ lệ trả hàng theo danh mục, tỉnh và tháng. Trình bày cặp khóa–giá trị đầu vào/đầu ra của Mapper và Reducer, bước Shuffle & Sort, Combiner (nếu phù hợp), Partitioner và ít nhất ba trường hợp kiểm thử. | `src/cau05_mapreduce/` |
| 6 | 1,0 | Dùng Apache Spark xây dựng DataFrame pipeline xác định sản phẩm tăng trưởng nhanh và khách hàng có nguy cơ rời bỏ. Có bước đọc CSV/JSON, làm sạch, join, ít nhất năm transformations và ba actions; dùng cache/persist hợp lý; so sánh thời gian và I/O dự kiến với MapReduce; xuất dữ liệu tổng hợp dạng CSV hoặc Parquet. | `src/cau06_spark/` |
| 7 | 1,0 | Thiết kế bảng HBase phục vụ truy cập ngẫu nhiên. RowKey đề xuất: `customer_id#reverse_timestamp`. Tối thiểu ba column families, mô tả version/timestamp, viết lệnh hoặc mã Client API cho create/put/get/scan/delete, đề xuất pre-splitting, TTL, compression, backup và quyền truy cập. | `src/cau07_hbase/` |
| 8 | 1,0 | Mô phỏng quy trình phân tích bằng BigSheets: định nghĩa collection, làm sạch và biến đổi dữ liệu, tạo calculated columns, lọc/nhóm/join, xây dựng dashboard doanh thu – hoàn trả – giao hàng theo danh mục và tỉnh. Nêu rõ các bước để người không lập trình tái tạo kết quả và xuất báo cáo. | `src/cau08_bigsheets/` |
| 9 | 1,0 | Dùng R kết nối tệp SQLite đi kèm bằng DBI/RSQLite, viết truy vấn SQL có JOIN và GROUP BY, đọc dữ liệu vào R, xử lý bằng dplyr/tidyr, trực quan hóa bằng ggplot2, thực hiện hồi quy doanh thu và phân loại khả năng trả hàng. Ghi bảng kết quả trở lại CSDL và đóng kết nối an toàn. | `src/cau09_r/` |
| 10 | 1,0 | Tích hợp thành báo cáo kỹ thuật hoàn chỉnh: đánh giá chất lượng dữ liệu, trả lời mục tiêu “tối ưu doanh thu, tỷ lệ hoàn trả và thời gian giao hàng”, đối chiếu Pig–MapReduce–Spark, đề xuất kiến trúc triển khai và ít nhất năm khuyến nghị có căn cứ từ dữ liệu. Kèm sơ đồ luồng dữ liệu, dashboard, mã nguồn và hướng dẫn tái lập. | `report/` |

## Dữ liệu (`data/`)

| Tệp | Mô tả |
|---|---|
| `orders.csv` | 15.000 đơn hàng, 23 cột, UTF-8 có BOM, thời gian ISO 8601 (01/2025 – 07/2026) |
| `customers.csv` | 1.200 khách hàng (danh mục) |
| `products.csv` | 400 sản phẩm (danh mục) |
| `events_stream.jsonl` | 5.000 sự kiện `order_event` dạng JSON Lines, mô phỏng luồng |
| `project_data.sqlite` | CSDL SQLite: `fact_main`, `entity_master`, `item_master` |
| `data_dictionary.csv` | Từ điển dữ liệu |

Dữ liệu giả lập phục vụ học tập, không chứa dữ liệu cá nhân thật. Cột `quality_flag` cố ý đánh dấu một phần nhỏ bản ghi MISSING/OUTLIER/LATE/DUPLICATE để thực hành làm sạch.
