# Trình bày theo từng ý của đề – Đề 01

Mỗi câu chép nguyên văn yêu cầu của đề, rồi tách thành từng ý. Ý nào **demo** thì có lệnh để copy dán, ý nào **lý thuyết** thì ghi chương, mục, bảng/hình và trang trong báo cáo.

**Quy ước:**
- **💻 Chạy:** dán vào tab **`may1`** (mở bằng `scripts\mo-terminal.cmd`). Riêng Câu 8, 9 dán vào ô **Console** của RStudio (`localhost:8787`).
- **👀 Thấy:** kết quả cần chỉ cho cô.
- **📄 Báo cáo:** vị trí trong `BaoCao.pdf`. Số trang theo bản PDF hiện tại; nếu đã chèn hàng "1. Nguồn" vào Bảng 1.10 thì từ trang 25 trở đi có thể lệch 1 trang.
- Muốn chạy cả câu một mạch thay vì từng ý: dùng `bash ~/src/demo/cauNN.sh` (xem [DEMO.md](DEMO.md)).

---

## Câu 1 (1,0 điểm)

> Phân tích đặc trưng Big Data của bài toán theo tối thiểu 5V. Phân loại các tệp và trường dữ liệu thành dữ liệu có cấu trúc, bán cấu trúc và dữ liệu luồng; chỉ rõ phần nào phù hợp phân tích tĩnh và phần nào cần xử lý gần thời gian thực.

### 1a. Phân tích đặc trưng Big Data theo 5V

💻 Chạy:
```bash
bash ~/src/demo/cau01.sh
```
👀 Thấy: 5 bước Volume → Velocity → Variety → Veracity → Value, cuối cùng là khung XONG mỗi V một dòng.

📄 Báo cáo: **Chương 1, mục 1.3. Phân tích đặc trưng Big Data**, trang **20–22**
- 1.3.1 Volume, **Bảng 1.3** Dung lượng các tệp dữ liệu, **Bảng 1.4** Ước tính dung lượng khi triển khai thực tế (tr. 20–21)
- 1.3.2 Velocity, 1.3.3 Variety, 1.3.4 Veracity (tr. 21)
- 1.3.5 Value, **Bảng 1.5** Ba chỉ số mục tiêu theo danh mục; 1.3.6 Variability, đặc trưng thứ 6 (tr. 22)

### 1b. Phân loại các **tệp** thành có cấu trúc, bán cấu trúc, luồng

💻 Chạy (xem tận mắt hình dạng từng loại):
```bash
head -2 /data/orders.csv; echo; head -1 /data/events_stream.jsonl; echo; ls -l /data
```
👀 Thấy: CSV là bảng có cột cố định (**có cấu trúc**); JSON có khóa lồng `payload` (**bán cấu trúc**); `events_stream.jsonl` là các sự kiện nối tiếp nhau (**luồng**).

📄 Báo cáo: **Chương 2, mục 2.1. Nguồn và mô tả dữ liệu**, **Bảng 2.1** Mô tả và phân loại các tệp dữ liệu (cột "Loại dữ liệu"), trang **26**

### 1c. Phân loại các **trường** dữ liệu

📄 Báo cáo (lý thuyết): **Chương 2, mục 2.2. Mô tả các thuộc tính**, trang **27–28**
- **Bảng 2.2** Thuộc tính của `orders.csv` (có cấu trúc), tr. 27
- **Bảng 2.3** Thuộc tính của `events_stream.jsonl` (bán cấu trúc, luồng), tr. 28
- **Bảng 2.4** Thuộc tính của `customers.csv`, `products.csv`, tr. 28

### 1d. Phần nào phân tích tĩnh, phần nào cần xử lý gần thời gian thực

📄 Báo cáo (lý thuyết): **Chương 1, mục 1.3.7. Phân tích tĩnh và xử lý gần thời gian thực**, trang **22**
- **Hình 1.1** Phân luồng dữ liệu theo chế độ xử lý tĩnh và gần thời gian thực
- **Bảng 1.6** Phân chia nhu cầu phân tích theo chế độ xử lý

---

## Câu 2 (1,0 điểm)

> Đề xuất kiến trúc thu thập và lưu trữ dữ liệu đầu–cuối. Thiết kế ít nhất hai kịch bản Flume: (i) nạp tệp CSV theo lô vào HDFS; (ii) nhận sự kiện `order_event` từ HTTP/Netcat/Kafka vào HDFS hoặc HBase. Viết cấu hình Source–Channel–Sink, giải thích lựa chọn MemoryChannel/FileChannel và cơ chế chống mất dữ liệu.

### 2a. Đề xuất kiến trúc thu thập và lưu trữ đầu–cuối

📄 Báo cáo (lý thuyết): **Chương 1, mục 1.5. Kiến trúc tổng thể hệ thống**, trang **25**
- **Hình 1.2** Kiến trúc thu thập, lưu trữ và xử lý dữ liệu đầu–cuối
- **Bảng 1.10** Các tầng của kiến trúc và cơ chế chịu lỗi

### 2b. Kịch bản (i): nạp tệp CSV theo lô vào HDFS

💻 Xem cấu hình:
```bash
grep -vE '^\s*#|^\s*$' ~/src/cau02_flume/conf/batch-csv.conf
```
💻 Chạy kịch bản (khoảng 1 phút):
```bash
bash ~/src/cau02_flume/run_batch.sh
```
👀 Thấy: 3 tệp orders, customers, products được đặt vào thư mục spool, Flume đọc rồi ghi vào `/btl/raw/<bảng>/ingest_date=<hôm nay>`. Dòng cuối: `PASS: 3 tep lo nap vao HDFS trung tung byte voi tep goc`.

📄 Báo cáo: **Chương 3, mục 3.3.2. Hai kịch bản Flume**, trang **40**; **Hình 3.4** Cấu hình Source–Channel–Sink của hai agent Flume, trang **41**

### 2c. Kịch bản (ii): nhận sự kiện `order_event` từ HTTP vào HDFS và HBase

💻 Xem cấu hình:
```bash
grep -vE '^\s*#|^\s*$' ~/src/cau02_flume/conf/stream-events.conf
```
💻 Chạy kịch bản (khoảng 1 phút):
```bash
bash ~/src/cau02_flume/run_stream.sh
```
👀 Thấy: gửi 5.000 sự kiện qua HTTP, rồi gửi lại 1.000. Ba dòng PASS cuối: HDFS 6.000 dòng (nhận ít nhất một lần), khử trùng còn 5.000, HBase đúng 5.000 dòng.

🌐 Mở: `http://localhost:16010` → Tables → `btl:order_events`

📄 Báo cáo: mục **3.3.2**, trang **40**; **Bảng 3.11** Kết quả chạy kịch bản (ii), trang **41**

### 2d. Viết cấu hình Source–Channel–Sink

💻 Hai tệp cấu hình đầy đủ (đã xem ở 2b, 2c):
```bash
cat ~/src/cau02_flume/conf/batch-csv.conf
```
```bash
cat ~/src/cau02_flume/conf/stream-events.conf
```
📄 Báo cáo: **Hình 3.4**, trang **41**; toàn văn ở **Phụ lục B**, mục "Mã nguồn Câu 2, 3", trang **70–71**

### 2e. Giải thích lựa chọn MemoryChannel/FileChannel và cơ chế chống mất dữ liệu

💻 Chạy thí nghiệm tắt đột ngột agent bằng `kill -9` (khoảng 2 phút):
```bash
bash ~/src/cau02_flume/crash_demo.sh
```
👀 Thấy: `FileChannel 1000 / 1000` (giữ đủ), `MemoryChannel 1000 / 0` (mất hết).

📄 Báo cáo: **Chương 3, mục 3.3.3. MemoryChannel, FileChannel và cơ chế chống mất dữ liệu**, **Bảng 3.12** So sánh MemoryChannel và FileChannel, trang **42**

---

## Câu 3 (1,0 điểm)

> Thiết kế vùng dữ liệu trên HDFS gồm raw, staging, curated và output. Đề xuất cấu trúc thư mục phân vùng theo thời gian và category; tính dung lượng lưu trữ khi nhân bản 3 lần; mô tả vai trò NameNode, DataNode, YARN và phương án khôi phục khi một node hỏng.

### 3a. Thiết kế 4 vùng raw, staging, curated, output

💻 Chạy:
```bash
hdfs dfs -ls /btl/raw /btl/staging /btl/curated /btl/output
```
🌐 Mở: `http://localhost:9870` → Utilities → Browse the file system → `/btl`

📄 Báo cáo: **Chương 3, mục 3.2.1. Vùng dữ liệu trên HDFS**, **Bảng 3.3** Bốn vùng dữ liệu trên HDFS, trang **34**

### 3b. Cấu trúc thư mục phân vùng theo thời gian và category

💻 Chạy:
```bash
hdfs dfs -ls /btl/raw/orders; hdfs dfs -ls -R /btl/curated/orders | awk '/^d/{print $8}' | head -10
```
👀 Thấy: vùng raw chia theo ngày nạp `ingest_date=YYYY-MM-DD`; vùng curated chia theo `year=/month=/category=`.

📄 Báo cáo: mục **3.2.1**, **Bảng 3.3**, trang **34**

### 3c. Tính dung lượng lưu trữ khi nhân bản 3 lần

💻 Chạy:
```bash
hdfs dfs -du -s -h /btl/raw /btl/staging /btl/curated /btl/output
```
👀 Thấy: cột 1 là dữ liệu, cột 2 là dung lượng chiếm thật (gấp 3). Ví dụ raw 6,9 MB → 20,7 MB.

📄 Báo cáo: **Bảng 3.4** Dung lượng các vùng trên cụm và **Bảng 3.5** Dự báo dung lượng HDFS năm đầu tiên, trang **35**

### 3d. Vai trò NameNode, DataNode, YARN

💻 Chạy:
```bash
hdfs dfsadmin -report | grep -E '^Live datanodes|^Name:'; yarn node -list
```
👀 Thấy: 3 DataNode đang sống và 3 NodeManager (YARN) RUNNING.

🌐 Mở: `http://localhost:9870` → Datanodes; `http://localhost:8088` → Nodes

📄 Báo cáo (lý thuyết): **Bảng 3.6** Vai trò các tiến trình HDFS và YARN trong cụm, trang **36**; thêm mục **1.4.1** Apache Flume, HDFS và YARN, **Bảng 1.7**, trang **23**

### 3e. Phương án khôi phục khi một node hỏng

💻 Chạy (khoảng 4 phút, trong lúc chạy không làm việc khác):
```bash
bash ~/src/demo/cau03_hong_node.sh
```
👀 Thấy: tắt DataNode trên datanode3 → đọc lại vẫn đúng → khoảng 143 s sau NameNode báo node chết → tự nhân bản lại → bật lại thì HDFS HEALTHY. Trong lúc chờ, bấm F5 trang `localhost:9870` → Datanodes để thấy datanode3 chuyển sang Dead.

📄 Báo cáo: **Bảng 3.7** Diễn biến khi tắt datanode3, trang **36**

---

## Câu 4 (1,0 điểm)

> Viết Pig Latin để LOAD các tệp, khai báo schema, FILTER bản ghi không hợp lệ, JOIN bảng sự kiện với hai bảng danh mục, GROUP theo category và customer_segment, sử dụng FOREACH, DISTINCT, ORDER, LIMIT, SPLIT và STORE. Bổ sung tối thiểu bốn hàm đánh giá như SUM, COUNT, AVG, MIN/MAX, SIZE, CONCAT hoặc TOKENIZE.

### 4a. Chạy kịch bản Pig

💻 Chạy (khoảng **5 phút**, nên bật từ đầu buổi ở một tab `ssh may1` riêng):
```bash
bash ~/src/cau04_pig/run.sh
```
👀 Thấy: `mapreduce_jobs=17`, `orders=14408 ...`, `Pig va MapReduce: compare_category_month.csv giong het nhau`.

🌐 Mở: `http://localhost:19888`: 17 job MapReduce do Pig sinh ra

📄 Báo cáo: **Chương 3, mục 3.5.1. Kịch bản Pig Latin (Câu 4)**, **Hình 3.6** Luồng dữ liệu của kịch bản Pig, trang **45**

### 4b. LOAD các tệp và khai báo schema

💻 Chạy:
```bash
sed -n 25,52p ~/src/cau04_pig/cau04.pig
```
👀 Thấy: 4 lệnh `LOAD ... AS (tên:kiểu, ...)` cho orders, customers, products, events.

### 4c. FILTER, JOIN, GROUP, FOREACH, DISTINCT, ORDER, LIMIT, SPLIT, STORE

💻 Chạy (in mọi dòng dùng các toán tử này, kèm số dòng):
```bash
grep -nwE 'LOAD|FILTER|JOIN|GROUP|FOREACH|DISTINCT|ORDER|LIMIT|SPLIT|STORE' ~/src/cau04_pig/cau04.pig
```
👀 Chỉ cho cô:
- `FILTER ... status != 'HEADER'` (dòng 68)
- `SPLIT valid INTO clean ..., rejected OTHERWISE` (dòng 73)
- `JOIN orders_c BY customer_id, customers ...` và `JOIN ... products ...` (dòng 104–105): JOIN bảng sự kiện đơn hàng với **hai bảng danh mục**
- `GROUP enriched BY (category, customer_segment)` (dòng 125)
- `DISTINCT`, `ORDER`, `LIMIT 10`, `STORE`

💻 Xem kết quả GROUP theo category × customer_segment:
```bash
hdfs dfs -cat /btl/output/cau04_pig/segment_stats/part-* | head -12
```
📄 Báo cáo: mục **3.5.1**, trang **45**; làm sạch ở **mục 2.4.1**, **Bảng 2.7** Các bước làm sạch bằng Pig, trang **30**; kết quả ở **mục 4.1.1**, **Bảng 4.1**, trang **49**

### 4d. Tối thiểu bốn hàm đánh giá

💻 Chạy:
```bash
grep -nE '\b(SUM|COUNT|AVG|MIN|MAX|SIZE|CONCAT)\(' ~/src/cau04_pig/cau04.pig
```
👀 Thấy: nhóm dùng **7 hàm**: SUM, COUNT, AVG, MIN, MAX, SIZE, CONCAT.

---

## Câu 5 (1,0 điểm)

> Xây dựng thuật toán MapReduce: tính tổng doanh thu và tỷ lệ trả hàng theo danh mục, tỉnh và tháng. Trình bày cặp khóa–giá trị đầu vào/đầu ra của Mapper và Reducer, bước Shuffle & Sort, Combiner (nếu phù hợp), Partitioner và ít nhất ba trường hợp kiểm thử.

### 5a. Tính tổng doanh thu và tỷ lệ trả theo danh mục, tỉnh, tháng

💻 Chạy (khoảng 1 phút, 3 job):
```bash
bash ~/src/cau05_mapreduce/run.sh
```
💻 Xem kết quả (danh mục, tỉnh, tháng, số đơn, doanh thu, số đơn trả, tỷ lệ trả %):
```bash
hdfs dfs -cat /btl/output/cau05_mr/category_province_month/part-r-00000 2>/dev/null | head -8
```
📄 Báo cáo: **Chương 3, mục 3.5.2. Thuật toán MapReduce (Câu 5)**, trang **46**

### 5b. Cặp khóa–giá trị đầu vào/đầu ra của Mapper và Reducer

💻 Xem các lớp Java:
```bash
grep -hE '^public (final )?class' ~/src/cau05_mapreduce/java/btl/cau05/*.java
```
👀 Thấy: `Mapper<LongWritable, Text, Text, OrderStats>` và `Reducer<Text, OrderStats, Text, Text>`.

📄 Báo cáo (lý thuyết): **Bảng 3.15** Cặp khóa–giá trị vào/ra của từng bước, trang **46**

### 5c. Bước Shuffle & Sort

📄 Báo cáo (lý thuyết): mục **3.5.2**, **Hình 3.7** Luồng dữ liệu của job MapReduce Câu 5, trang **46**

### 5d. Combiner

💻 Chạy:
```bash
grep -hE 'COMBINER|COMBINE_(INPUT|OUTPUT)_RECORDS|REDUCE_SHUFFLE_BYTES' ~/src/cau05_mapreduce/output/counters_category_province_month*.txt
```
👀 Thấy: 14.408 → 2.049 bản ghi qua shuffle (giảm 85,8%); shuffle 742.292 → 105.658 byte.

🌐 Mở: `http://localhost:19888` → job `cau05 category_province_month` → menu trái **Counters**

📄 Báo cáo: **Chương 4, mục 4.1.2**, **Bảng 4.2** Counter của job có và không có Combiner, trang **49–50**

### 5e. Partitioner

💻 Chạy:
```bash
cat ~/src/cau05_mapreduce/output/partitions.txt
```
👀 Thấy: 6 danh mục chia cho 3 reducer, mỗi reducer 2 danh mục.

📄 Báo cáo: mục **3.5.2**, trang **46**

### 5f. Ít nhất ba trường hợp kiểm thử

💻 Chạy (khoảng 30 giây):
```bash
bash ~/src/cau05_mapreduce/test.sh
```
👀 Thấy: 5 dòng `PASS: TC1` … `PASS: TC5`.

📄 Báo cáo: **Bảng 3.16** Trường hợp kiểm thử của Câu 5, trang **47**

---

## Câu 6 (1,0 điểm)

> Dùng Apache Spark xây dựng DataFrame pipeline xác định sản phẩm tăng trưởng nhanh và khách hàng có nguy cơ rời bỏ. Có bước đọc CSV/JSON, làm sạch, join, ít nhất năm transformations và ba actions; dùng cache/persist hợp lý; so sánh thời gian và I/O dự kiến với MapReduce; xuất dữ liệu tổng hợp dạng CSV hoặc Parquet.

### 6a. Chạy pipeline Spark

💻 Chạy (khoảng 1 phút):
```bash
bash ~/src/cau06_spark/run.sh
```
👀 Thấy: `orders raw: 15000 | sau lam sach: 14408`, `KET QUA: OK`.

🌐 Mở: `http://localhost:18080` → app mới nhất → Jobs, Stages, Storage

📄 Báo cáo: **Chương 3, mục 3.4. Cài đặt xử lý bằng Spark/PySpark**, **Hình 3.5** Luồng DataFrame, trang **42–43**

### 6b. Sản phẩm tăng trưởng nhanh và khách hàng có nguy cơ rời bỏ

💻 Chạy:
```bash
head -6 ~/src/cau06_spark/output/fast_growing_products.csv | cut -d, -f1-5,10; cat ~/src/cau06_spark/output/churn_summary.csv
```
👀 Thấy: 64 sản phẩm tăng nhanh; 369 khách nguy cơ (147 HIGH + 222 MEDIUM).

📄 Báo cáo: **Chương 4, mục 4.2.2**, **Bảng 4.4**, trang **51**

### 6c. Đọc CSV/JSON, làm sạch, join

💻 Chạy:
```bash
grep -nE 'spark\.read|# T1|# T3' ~/src/cau06_spark/pipeline.py
```
📄 Báo cáo: **Chương 2, mục 2.4.2**, **Bảng 2.9**, trang **31**; **mục 3.4.3** Join, groupBy và Spark SQL, trang **44**

### 6d. Ít nhất năm transformations và ba actions

💻 Chạy:
```bash
grep -nE '# T[0-9]|# A[0-9]' ~/src/cau06_spark/pipeline.py
```
👀 Thấy: **7 transformation** (T1–T7) và **9 action** (A1–A9).

📄 Báo cáo: mục **3.4.2**, **Bảng 3.13** Các transformation, **Bảng 3.14** Các action, trang **43**

### 6e. Dùng cache/persist hợp lý

💻 Chạy:
```bash
grep -nE 'persist|unpersist|cache' ~/src/cau06_spark/pipeline.py
```
👀 Thấy: `enriched.persist(MEMORY_AND_DISK)` vì DataFrame này được dùng lại cho nhiều action, xong thì `unpersist()`.

📄 Báo cáo: mục **3.4.2**, trang **43**

### 6f. So sánh thời gian và I/O dự kiến với MapReduce

📄 Báo cáo (lý thuyết + số đo): **Chương 4, mục 4.4. Đánh giá hiệu năng**, **Bảng 4.9** Kết quả thử nghiệm hiệu năng (tr. **58**), **Bảng 4.10** So sánh I/O MapReduce (ước tính) và Spark (đo được) (tr. **59**)

### 6g. Xuất dữ liệu tổng hợp dạng CSV hoặc Parquet

💻 Chạy:
```bash
hdfs dfs -ls /btl/output/cau06_spark; hdfs dfs -ls /btl/output/cau06_spark/fast_growing_products
```
👀 Thấy: thư mục CSV (`fast_growing_products`, `churn_risk_customers`, `category_month`) và Parquet (`product_growth`, `customer_churn`, vùng `/btl/curated/orders`).

📄 Báo cáo: **mục 3.6. Lưu và xuất kết quả**, **Bảng 3.17**, trang **48**

---

## Câu 7 (1,0 điểm)

> Thiết kế bảng HBase phục vụ truy cập ngẫu nhiên. RowKey đề xuất: `customer_id#reverse_timestamp`. Tối thiểu ba column families, mô tả version/timestamp, viết lệnh hoặc mã Client API cho create/put/get/scan/delete, đề xuất pre-splitting, TTL, compression, backup và quyền truy cập.

### 7a. Tạo bảng, nạp dữ liệu, chạy toàn bộ thao tác

💻 Chạy trước (khoảng 1,5 phút):
```bash
bash ~/src/cau07_hbase/run.sh
```
📄 Báo cáo: **Chương 3, mục 3.2.2. Thiết kế bảng HBase**, trang **37**

### 7b. RowKey `customer_id#reverse_timestamp`, truy cập ngẫu nhiên

💻 Chạy (lấy 5 đơn mới nhất của khách C00941 trong một lần quét):
```bash
echo "scan 'btl:customer_orders', {ROWPREFIXFILTER => 'C00941#', COLUMNS => ['o:order_id', 'o:ts'], LIMIT => 5}" | hbase shell -n 2>/dev/null | grep -E 'column=|row'
```
👀 Thấy: đơn mới nhất nằm trên cùng, không cần sắp xếp.

📄 Báo cáo: **Hình 3.2** Bố trí dòng theo rowkey và truy vấn đơn mới nhất, trang **37**

### 7c. Tối thiểu ba column families; pre-splitting, TTL, compression

💻 Chạy:
```bash
echo "describe 'btl:customer_orders'" | hbase shell -n 2>/dev/null | grep '^{NAME'
```
👀 Thấy: 3 family `o`, `m`, `d`; `VERSIONS => '5'` ở `d`; `TTL => 1095 DAYS`; `COMPRESSION => 'SNAPPY'`.

🌐 Mở: `http://localhost:16010` → Tables → `btl:customer_orders`: **6 region** (pre-split)

💻 Xem điểm chia region và hiệu quả nén:
```bash
grep -n 'SPLITS =' ~/src/cau07_hbase/CustomerOrders.java; cat ~/src/cau07_hbase/output/compression.txt
```
📄 Báo cáo: **Bảng 3.8** Ba column family (tr. **37**); **Bảng 3.9** Dung lượng HFile với hai cấu hình, nén nhỏ hơn 5,79 lần (tr. **38**)

### 7d. Mô tả version/timestamp

💻 Chạy (lịch sử trạng thái của một đơn bị trả):
```bash
echo "get 'btl:customer_orders', 'C00941#9223370277765036807', {COLUMN => 'd:status', VERSIONS => 5}" | hbase shell -n 2>/dev/null | grep timestamp
```
👀 Thấy: 3 phiên bản PLACED → DELIVERED → RETURNED, mỗi phiên bản có timestamp riêng.

📄 Báo cáo: mục **3.2.2**, **Bảng 3.8**, trang **37**

### 7e. Lệnh / mã Client API cho create, put, get, scan, delete

💻 Xem kết quả Java Client API và hbase shell (đã chạy ở 7a):
```bash
cat ~/src/cau07_hbase/output/client_api_demo.txt
```
```bash
less ~/src/cau07_hbase/output/shell_demo.txt
```
(bấm `q` để thoát `less`)

📄 Báo cáo: **Bảng 3.10** Các thao tác create/put/get/scan/delete bằng hbase shell và Java Client API (tr. **39**); **mục 3.5.3. HBase Client API (Câu 7)** (tr. **47**)

### 7f. Backup và quyền truy cập

💻 Chạy:
```bash
echo "list_snapshots" | hbase shell -n 2>/dev/null; cat ~/src/cau07_hbase/output/acl_backup.txt
```
👀 Thấy:
- snapshot `customer_orders_snap`, `ExportSnapshot: OK` sang `/btl/backup/hbase`;
- user `analyst` có quyền R thì đọc được, ghi bị từ chối, bị revoke thì hết đọc.

📄 Báo cáo: mục **3.2.2**, trang **37–38**

---

## Câu 8 (1,0 điểm)

> Mô phỏng quy trình phân tích bằng BigSheets: định nghĩa collection, làm sạch và biến đổi dữ liệu, tạo calculated columns, lọc/nhóm/join, xây dựng dashboard doanh thu – hoàn trả – giao hàng theo danh mục và tỉnh. Nêu rõ các bước để người không lập trình tái tạo kết quả và xuất báo cáo.

### 8a. Chạy mô phỏng (RStudio)

💻 Dán vào ô **Console** của RStudio (`http://localhost:8787`):
```r
setwd("~/src/cau08_bigsheets"); source("dashboard.R")
```
📄 Báo cáo: **Chương 4, mục 4.3. Trực quan hóa**, trang **54**

### 8b. Collection, làm sạch, calculated columns, lọc/nhóm/join

💻 Chạy ở tab `may1` (các bước B1–B8 trong mã và số dòng sau mỗi bước):
```bash
grep -nE '^# B[0-9]' ~/src/cau08_bigsheets/dashboard.R; cat ~/src/cau08_bigsheets/output/buoc_bigsheets.csv
```
👀 Thấy:
- B1 Collection: 15.000 / 1.200 / 400 dòng
- B3 Filter (làm sạch): 14.408
- B4 Calculated columns (`order_month`, `is_late`, `revenue_bucket`…)
- B5 Join
- B6 Group

### 8c. Dashboard doanh thu – hoàn trả – giao hàng theo danh mục và tỉnh

💻 Trong RStudio: ô **Files** → `src/cau08_bigsheets/output/hinh/` → bấm `cau08-dashboard.png`

📄 Báo cáo: **Hình 4.3** Dashboard tổng hợp theo danh mục và tỉnh giao hàng (tr. **55**); mục **4.3.2–4.3.4**, **Hình 4.5**, **Bảng 4.7** (tr. **56–57**); ảnh ở **Phụ lục C.1** (tr. **89**)

### 8d. Các bước để người không lập trình tái tạo kết quả và xuất báo cáo

💻 Chạy ở tab `may1`:
```bash
less ~/src/cau08_bigsheets/huong-dan-bigsheets.md
```
👀 Thấy: hướng dẫn bấm từng bước trên giao diện BigSheets (Workbook → Filter → Calculated column → Join → Pivot → Chart → Dashboard → Export), mỗi bước có bảng số dòng để đối chiếu.

📄 Báo cáo: mục **1.4.4. BigSheets và R** (tr. **24**), mục **4.3** (tr. **54**)

---

## Câu 9 (1,0 điểm)

> Dùng R kết nối tệp SQLite đi kèm bằng DBI/RSQLite, viết truy vấn SQL có JOIN và GROUP BY, đọc dữ liệu vào R, xử lý bằng dplyr/tidyr, trực quan hóa bằng ggplot2, thực hiện hồi quy doanh thu và phân loại khả năng trả hàng. Ghi bảng kết quả trở lại CSDL và đóng kết nối an toàn.

### 9a. Chạy toàn bộ (RStudio)

💻 Dán vào ô **Console** của RStudio:
```r
setwd("~/src/cau09_r"); source("phan_tich.R")
```
👀 Thấy: Console in lần lượt `== 1. Ket noi SQLite`, `== 2. Truy van SQL`, `== 3. dplyr/tidyr`, `== 4. Hoi quy`, `== 5. Phan loai`, `== 6. Ghi ket qua`, `== 7. Bieu do`.

### 9b. Kết nối SQLite bằng DBI/RSQLite, đóng kết nối an toàn

💻 Chạy ở tab `may1`:
```bash
grep -nE 'dbConnect|dbDisconnect|on.exit|dbIsValid' ~/src/cau09_r/phan_tich.R
```
👀 Thấy: `dbConnect(RSQLite::SQLite(), ...)`; `on.exit(dbDisconnect(con))` (đóng cả khi có lỗi); cuối script kiểm tra `dbIsValid = FALSE`.

### 9c. Truy vấn SQL có JOIN và GROUP BY

💻 Chạy ở tab `may1`:
```bash
sed -n 119,135p ~/src/cau09_r/phan_tich.R
```
👀 Thấy: `JOIN item_master ... JOIN entity_master ... GROUP BY i.category, e.customer_segment`.

📄 Báo cáo: **Bảng 4.3** Tỷ lệ trả hàng theo danh mục × phân khúc (tr. **51**); **Hình 4.4** (tr. **56**)

### 9d. Xử lý bằng dplyr/tidyr, trực quan hóa bằng ggplot2

💻 Chạy ở tab `may1`:
```bash
grep -nE 'pivot_wider|pivot_longer|ggplot\(' ~/src/cau09_r/phan_tich.R
```
💻 Trong RStudio: **Files** → `src/cau09_r/output/hinh/` → mở các ảnh `cau09-*.png`

📄 Báo cáo: **Hình 4.7** Tỷ lệ hoàn trả theo 7 yếu tố (tr. **58**)

### 9e. Hồi quy doanh thu

💻 Chạy ở tab `may1`:
```bash
cat ~/src/cau09_r/output/hoi_quy_so_sanh.csv
```
👀 Thấy: mô hình M3 có `r2_test = 0.8325`.

📄 Báo cáo: **mục 4.2.4**, **Bảng 4.5** So sánh các mô hình hồi quy (tr. **52**), **Hình 4.1** (tr. **53**)

### 9f. Phân loại khả năng trả hàng

💻 Chạy ở tab `may1`:
```bash
cat ~/src/cau09_r/output/phan_loai_chi_so.csv; cat ~/src/cau09_r/output/kiem_dinh_chi2.csv
```
👀 Thấy:
- `auc_test = 0.4933`, ngang mô hình cơ sở;
- kiểm định χ² có mọi p > 0,12, tức dữ liệu không có tín hiệu.

📄 Báo cáo: **mục 4.2.5**, **Bảng 4.6** (tr. **54**), **Hình 4.2** Đường ROC (tr. **54**)

### 9g. Ghi bảng kết quả trở lại CSDL

💻 Chạy ở tab `may1`:
```bash
cat ~/src/cau09_r/output/bang_ghi_lai_csdl.txt
```
👀 Thấy: 16 bảng `kq_*` đã ghi vào `project_data_results.sqlite`.

📄 Báo cáo: **Phụ lục C.2** (tr. **89**)

---

## Câu 10 (1,0 điểm)

> Tích hợp thành báo cáo kỹ thuật hoàn chỉnh: đánh giá chất lượng dữ liệu, trả lời mục tiêu "tối ưu doanh thu, tỷ lệ hoàn trả và thời gian giao hàng", đối chiếu Pig–MapReduce–Spark, đề xuất kiến trúc triển khai và ít nhất năm khuyến nghị có căn cứ từ dữ liệu. Kèm sơ đồ luồng dữ liệu, dashboard, mã nguồn và hướng dẫn tái lập.

### 10a. Báo cáo kỹ thuật hoàn chỉnh

📄 Cả quyển báo cáo (92 trang, theo mẫu CTKU122).

### 10b. Đánh giá chất lượng dữ liệu

📄 Báo cáo: **Chương 2, mục 2.3. Khảo sát chất lượng dữ liệu**, **Bảng 2.5**, **Bảng 2.6** (tr. **29**); **mục 2.5**, **Bảng 2.10** (tr. **32**)

### 10c. Trả lời mục tiêu tối ưu doanh thu, tỷ lệ hoàn trả, thời gian giao hàng

📄 Báo cáo: **mục 4.2.1** KPI tổng quan theo ba mục tiêu (tr. **50**); **mục 4.5.3**, **Bảng 4.13** Mức độ đạt các mục tiêu (tr. **61**)

### 10d. Đối chiếu Pig – MapReduce – Spark

💻 Chạy:
```bash
bash ~/src/demo/cau10.sh
```
👀 Thấy: 3 mã md5 giống hệt nhau, `So o sai khac: 0`, bảng thời gian MapReduce, Spark, Pig.

📄 Báo cáo: **mục 4.5.1**, **Bảng 4.11** (tr. **60**); **mục 4.5.2**, **Bảng 4.12** (tr. **60**)

### 10e. Đề xuất kiến trúc triển khai

📄 Báo cáo: **mục 1.5**, **Hình 1.2** (tr. **25**); **mục 3.1. Môi trường triển khai**, **Hình 3.1** Sơ đồ cụm (tr. **33**); hướng phát triển **mục 5.3** (tr. **64**)

### 10f. Ít nhất năm khuyến nghị có căn cứ

📄 Báo cáo: **mục 4.5.4. Khuyến nghị**, **Bảng 4.14** (7 khuyến nghị), trang **62**

### 10g. Sơ đồ luồng dữ liệu, dashboard, mã nguồn, hướng dẫn tái lập

📄 Báo cáo:
- Sơ đồ luồng dữ liệu: **Hình 1.2** (tr. **25**), **Hình 3.3** Các bước của pipeline (tr. **40**)
- Dashboard: **Hình 4.3** (tr. **55**)
- Mã nguồn: **Phụ lục B** (tr. **69–87**)
- Hướng dẫn tái lập: **Phụ lục A** (tr. **68**)
