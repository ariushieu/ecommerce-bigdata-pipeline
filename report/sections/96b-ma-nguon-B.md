### Mã nguồn – thành viên B

Toàn bộ mã nằm ở `src/cau02_flume/` và `src/cau03_hdfs/`. Lệnh chạy và kết quả được ghi trong `README.md` của từng thư mục. Dưới đây là các đoạn quan trọng nhất.

**B.1. Kịch bản Flume (ii): HTTP → FileChannel/HDFS + MemoryChannel/HBase** (`src/cau02_flume/conf/stream-events.conf`, rút gọn)

```properties
s1.sources  = httpSrc
s1.channels = fcEvents mcEvents
s1.sinks    = hdfsEvents hbaseEvents

# Source: HTTP + JSONHandler, chep moi event sang ca hai channel
s1.sources.httpSrc.type = http
s1.sources.httpSrc.port = 41414
s1.sources.httpSrc.handler = org.apache.flume.source.http.JSONHandler
s1.sources.httpSrc.channels = fcEvents mcEvents
s1.sources.httpSrc.selector.type = replicating

# Nhanh lop lo: FileChannel ben vung (log + checkpoint kep)
s1.channels.fcEvents.type = file
s1.channels.fcEvents.checkpointDir = /home/hadoop/flume-data/cau02/fc-stream/checkpoint
s1.channels.fcEvents.backupCheckpointDir = /home/hadoop/flume-data/cau02/fc-stream/checkpoint-backup
s1.channels.fcEvents.useDualCheckpoints = true
s1.channels.fcEvents.dataDirs = /home/hadoop/flume-data/cau02/fc-stream/data
s1.channels.fcEvents.capacity = 1000000
s1.channels.fcEvents.transactionCapacity = 1000

# Nhanh lop toc do: MemoryChannel
s1.channels.mcEvents.type = memory
s1.channels.mcEvents.capacity = 20000
s1.channels.mcEvents.transactionCapacity = 1000

# HDFS sink: partition theo ngay nhan, tep dang ghi an duoi tien to "_"
s1.sinks.hdfsEvents.type = hdfs
s1.sinks.hdfsEvents.channel = fcEvents
s1.sinks.hdfsEvents.hdfs.path = hdfs://masternode:9000/btl/raw/events/ingest_date=%Y-%m-%d
s1.sinks.hdfsEvents.hdfs.useLocalTimeStamp = true
s1.sinks.hdfsEvents.hdfs.filePrefix = events
s1.sinks.hdfsEvents.hdfs.fileSuffix = .jsonl
s1.sinks.hdfsEvents.hdfs.inUsePrefix = _
s1.sinks.hdfsEvents.hdfs.fileType = DataStream
s1.sinks.hdfsEvents.hdfs.rollSize = 133169152
s1.sinks.hdfsEvents.hdfs.rollCount = 0
s1.sinks.hdfsEvents.hdfs.rollInterval = 600
s1.sinks.hdfsEvents.hdfs.idleTimeout = 60

# HBase2 sink: regex tach JSON, nhom 1 (event_id) lam rowkey -> ghi lai idempotent
s1.sinks.hbaseEvents.type = hbase2
s1.sinks.hbaseEvents.channel = mcEvents
s1.sinks.hbaseEvents.table = btl:order_events
s1.sinks.hbaseEvents.columnFamily = e
s1.sinks.hbaseEvents.serializer = org.apache.flume.sink.hbase2.RegexHBase2EventSerializer
s1.sinks.hbaseEvents.serializer.regex = ^[{]"event_id": ?"([^"]+)", ?"event_time": ?"([^"]+)", ?"event_type": ?"([^"]+)", ?"source": ?"([^"]+)", ?"payload": ?[{]"category": ?"([^"]+)", ?"customer_segment": ?"([^"]+)", ?"net_revenue": ?([-0-9.eE]+), ?"returned_flag": ?([0-9]+)[}][}]$
s1.sinks.hbaseEvents.serializer.colNames = ROW_KEY,event_time,event_type,source,category,customer_segment,net_revenue,returned_flag
s1.sinks.hbaseEvents.serializer.rowKeyIndex = 0
```

Biểu thức chính quy dùng `[{]`, `[}]` thay cho `\{`, `\}`, vì tệp `.properties` của Java bỏ ký tự `\` đứng trước ký tự thường. Bảng được tạo bằng HBase shell:

```ruby
create 'btl:order_events', {NAME => 'e', VERSIONS => 1, COMPRESSION => 'SNAPPY', TTL => 15552000, BLOOMFILTER => 'ROW'}
```

**B.2. Kịch bản Flume (i): spooldir → FileChannel → HDFS** (`src/cau02_flume/conf/batch-csv.conf`, rút gọn một nguồn; hai nguồn `customers`, `products` khai báo tương tự)

```properties
b1.sources.srcOrders.type = spooldir
b1.sources.srcOrders.spoolDir = /home/hadoop/flume-data/cau02/spool/orders
b1.sources.srcOrders.ignorePattern = ^.*[.]tmp$
b1.sources.srcOrders.deletePolicy = never
b1.sources.srcOrders.basenameHeader = true
b1.sources.srcOrders.interceptors = tbl
b1.sources.srcOrders.interceptors.tbl.type = static
b1.sources.srcOrders.interceptors.tbl.key = table
b1.sources.srcOrders.interceptors.tbl.value = orders

b1.sinks.hdfsRaw.hdfs.path = hdfs://masternode:9000/btl/raw/%{table}/ingest_date=%Y-%m-%d
b1.sinks.hdfsRaw.hdfs.filePrefix = %{basename}
b1.sinks.hdfsRaw.hdfs.fileSuffix = .csv
b1.sinks.hdfsRaw.hdfs.rollSize = 133169152
b1.sinks.hdfsRaw.hdfs.rollInterval = 0
b1.sinks.hdfsRaw.hdfs.idleTimeout = 30
```

**B.3. Phát lại luồng sự kiện có giữ nhịp và gửi lại khi lỗi** (`src/cau02_flume/replay_events.py`, trích hàm chính)

```python
for i in range(0, len(events), a.batch):
    lo = events[i:i + a.batch]
    # giu nhip: lo thu k duoc gui khong som hon t0 + (so event da gui)/rate
    if a.rate > 0:
        cho = t0 + sent / a.rate - time.monotonic()
        if cho > 0:
            time.sleep(cho)
    lan = 0
    while True:
        try:
            code = gui_lo(a.url, lo, a.timeout)   # POST [{"headers":..., "body":...}, ...]
            if code == 200:
                break
            loi = "HTTP %d" % code
        except urllib.error.HTTPError as e:       # 503: channel day / loi put
            loi = "HTTP %d" % e.code
        except (urllib.error.URLError, OSError) as e:
            loi = str(e)
        lan += 1
        retries += 1
        if lan > a.retries:
            return 2
        time.sleep(min(0.2 * 2 ** lan, 5.0))     # backoff luy thua
    sent += len(lo)
```

**B.4. Kiểm chứng kịch bản (i): tệp trên HDFS trùng từng byte với tệp gốc** (`src/cau02_flume/run_batch.sh`, trích)

```bash
for t in orders customers products; do
  f=$(hdfs dfs -ls "$RAW/$t/ingest_date=*/${t}_$LO.*.csv" | awk '/^-/{print $8}')
  m1=$(md5sum < "$DATA/$t.csv" | cut -c1-32)
  m2=$(hdfs dfs -cat "$f" | md5sum | cut -c1-32)
  r=$(hdfs dfs -stat %r "$f")                       # he so nhan ban = 3
  if [ "$m1" = "$m2" ]; then kq="trung khop"; else kq="KHAC"; LOI=1; fi
done
```

**B.5. Tạo vùng và nạp bản chụp chuẩn, chạy lại an toàn** (`src/cau03_hdfs/init_zones.sh`, trích)

```bash
hdfs dfs -mkdir -p /btl/raw /btl/staging /btl/curated /btl/output
nap() {  # nap <bang> <tep>
  local dst="/btl/raw/$1/ingest_date=$SNAPSHOT"
  if hdfs dfs -test -e "$dst/$2" && [ "$FORCE" != "--force" ]; then
    echo "  da co  $dst/$2"; return
  fi
  hdfs dfs -mkdir -p "$dst"
  hdfs dfs -put -f "$DATA/$2" "$dst/$2"
}
```

**B.6. Demo khôi phục khi hỏng node** (`src/cau03_hdfs/recovery_demo.sh`, trích các bước chính, chạy trên máy thật)

```bash
# tep he so 2, block 1 MiB -> ~9 block, NameNode co cho de nhan ban lai
m "cat /data/orders.csv /data/orders.csv /data/orders.csv /data/orders.csv \
   | hdfs dfs -D dfs.blocksize=1048576 -D dfs.replication=2 -put - $DEMO/orders_x4_rep2.csv"
docker stop datanode3                                         # gia lap hong node
cho 420 10 "NameNode danh dau 1 DataNode dead" la_dead          # ~150 s
cho 300 10 "tep rep2 du 2 ban sao tren datanode1 + datanode2" rep2_du
docker start datanode3
docker exec datanode3 su - hadoop -c 'hdfs --daemon start datanode; yarn --daemon start nodemanager; hbase-daemon.sh start regionserver'
cho 300 10 "khong con block thieu ban sao trong /btl va tep demo" het_thieu
```

**B.7. Cây thư mục thực tế trên HDFS** (rút gọn từ `src/cau03_hdfs/zones_report.sh`)

```
/btl
├── raw/                                   chỉ thêm, không sửa
│   ├── orders/
│   │   ├── ingest_date=2026-08-01/orders.csv                                  bản chụp chuẩn
│   │   └── ingest_date=2026-10-11/orders_20261011-225900.1791734345694.csv    Flume (i)
│   ├── customers/ …   products/ …                                            (như orders)
│   └── events/
│       ├── ingest_date=2026-08-01/events_stream.jsonl                         bản chụp chuẩn
│       └── ingest_date=2026-10-11/events.1791734447244.jsonl                  Flume (ii)
├── staging/orders/part-m-00000                                                Pig
├── curated/orders/year=2025/month=01/category=Beauty/part-…c000.snappy.parquet   Spark
│                  … 19 tháng × 6 danh mục = 114 thư mục lá
├── output/cau04_pig/…  cau05_mr/…  cau06_spark/…
└── backup/hbase/                                                              snapshot HBase (Câu 7)
```

**B.8. Tham số của agent `b1` (kịch bản Flume (i))**

*[Bảng:c02-tham-so-lo]. Các tham số chính của agent `b1`*

| Thành phần | Tham số | Giá trị | Lý do |
|---|---|---|---|
| spooldir | `ignorePattern`, cách đặt tệp | `^.*[.]tmp$`; chép thành `<tên>.tmp` rồi `mv` | Spooldir yêu cầu tệp đã ghi xong và không đổi. Phép `mv` trong cùng hệ tệp là nguyên tử |
| spooldir | tên tệp lô | `<bảng>_YYYYmmdd-HHMMSS` | Spooldir dừng nếu gặp lại tên tệp đã nạp |
| spooldir | `deletePolicy`, `basenameHeader` | `never`, `true` | Tệp đã nạp được đổi tên `.COMPLETED` để làm bằng chứng; tên lô đi theo event để đặt tên tệp HDFS |
| spooldir | `deserializer`, `inputCharset` | `LINE`, UTF-8 | Mỗi dòng CSV là một event; BOM và CRLF được giữ nguyên |
| FileChannel | `capacity`, `transactionCapacity` | 1.000.000; 10.000 | Chứa được khoảng 65 lần tệp `orders` (15.001 dòng), đủ đệm khi HDFS tạm ngừng |
| HDFS sink | `hdfs.path`, `filePrefix` | `/btl/raw/%{table}/ingest_date=%Y-%m-%d`, `%{basename}` | Phân vùng theo ngày nạp; mỗi tệp lô thành một tệp HDFS riêng, truy được nguồn gốc |
| HDFS sink | `fileType`, `inUsePrefix` | `DataStream`, `_` | Ghi nguyên văn. Tệp đang ghi có tên `_….tmp` nên Pig, MapReduce, Spark bỏ qua |
| HDFS sink | `rollSize`, `rollCount`, `rollInterval`, `idleTimeout` | 127 MiB, 0, 0, 30 s | Tệp không vượt một block 128 MiB; lô đã nạp xong được đóng sau 30 s không có dữ liệu mới |

**Nhận xét [Bảng:c02-tham-so-lo]:**
- Vùng raw giữ **nguyên văn** dữ liệu nguồn, nên kịch bản (i) không bỏ BOM hay dòng tiêu đề; việc đó dành cho Pig khi ghi staging.
- Dùng `%{basename}` làm tiền tố giúp mỗi tệp HDFS là bản sao đúng một tệp lô, kiểm tra được bằng md5. Cái giá là mỗi lô sinh một tệp; nếu lô nhỏ và dày, cần gộp lô ở nguồn hoặc gộp tệp định kỳ (mục 3.2.1).
