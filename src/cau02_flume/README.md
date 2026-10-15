# Câu 2 – Thu thập dữ liệu bằng Flume

**Yêu cầu:** Hai kịch bản Flume: (i) nạp CSV theo lô vào HDFS; (ii) nhận `order_event` qua HTTP/Netcat vào HDFS hoặc HBase. Giải thích Memory/FileChannel và cơ chế chống mất dữ liệu.

**Bài viết:** mục 1.4.1, 1.5, 3.3 và Phụ lục B của báo cáo – [`report/sections/14b-*.md`, `15-*.md`, `33-*.md`, `96b-*.md`](../../report/sections/).

**Phụ trách:** Nguyễn Trần Khánh Duy – thành viên B (xem [phân công](../../README.md#phân-công-mỗi-người-20)). Quy ước chung: [`docs/quy-uoc.md`](../../docs/quy-uoc.md).

## Hai kịch bản

| Kịch bản | Source | Channel | Sink | Đích |
|---|---|---|---|---|
| (i) `conf/batch-csv.conf`, agent `b1` | 3 × `spooldir` (orders, customers, products) + interceptor `table` | FileChannel `fcBatch` | HDFS (DataStream) | `/btl/raw/<bảng>/ingest_date=<ngày nạp>/<tên lô>.<số đếm>.csv` |
| (ii) `conf/stream-events.conf`, agent `s1` | `http` cổng 41414, `JSONHandler`, selector `replicating` | FileChannel `fcEvents` + MemoryChannel `mcEvents` | HDFS + HBase2 (`RegexHBase2EventSerializer`, rowkey = `event_id`) | `/btl/raw/events/ingest_date=<ngày nhận>/events.<số đếm>.jsonl` và bảng `btl:order_events` (cf `e`) |

Flume chỉ ghi các partition theo **ngày chạy thật**; không ghi vào bản chụp `ingest_date=2026-08-01` (do `cau03_hdfs/init_zones.sh` nạp).

## Chạy (trong `ssh may1`, thư mục `~/src`)

```bash
bash cau02_flume/run_batch.sh     # (i)  ~45 s: đặt 3 tệp vào spool, chờ nạp xong, so md5 với tệp gốc
bash cau02_flume/run_stream.sh    # (ii) ~3 phút: tạo bảng HBase, bật agent, phát lại 5.000 sự kiện, gửi lại 1.000, đếm
bash cau02_flume/crash_demo.sh    # thí nghiệm kill -9 agent: FileChannel giữ được, MemoryChannel mất (~1 phút)
bash cau02_flume/test.sh          # CI: chạy cả hai kịch bản trên đường dẫn/bảng/cổng riêng rồi dọn sạch

# chạy tay một agent
flume-ng agent -n s1 -c $FLUME_HOME/conf -f cau02_flume/conf/stream-events.conf \
  -Dflume.monitoring.type=http -Dflume.monitoring.port=34545
python3 cau02_flume/replay_events.py --rate 250 --batch 50      # gửi vào http://localhost:41414
curl -s localhost:34545/metrics | python3 -m json.tool             # số liệu source/channel/sink
```

Cổng 41414 được mở ra máy thật, nên có thể gửi sự kiện từ Windows: `python replay_events.py --url http://localhost:41414` (nếu máy có Python 3) hoặc `curl -X POST -d '[{"headers":{},"body":"{...}"}]' http://localhost:41414`.

Tham số đổi được bằng biến môi trường (`lib.sh`): `FLUME_WORK` (spool + FileChannel, mặc định `~/flume-data/cau02`), `RAW_ROOT` (`/btl/raw`), `HTTP_PORT` (41414), `HB_TABLE` (`btl:order_events`), `MON_PORT` (34545), `RATE` (250 sự kiện/s), `RESEND` (1.000).

## Tệp

| Tệp | Nội dung |
|---|---|
| `conf/batch-csv.conf` | Kịch bản (i): spooldir → FileChannel → HDFS |
| `conf/stream-events.conf` | Kịch bản (ii): HTTP → replicating → FileChannel/HDFS + MemoryChannel/HBase |
| `replay_events.py` | Phát lại `events_stream.jsonl` theo lô, giữ nhịp sự kiện/giây, tự gửi lại khi nhận HTTP 503 (chỉ dùng thư viện chuẩn) |
| `lib.sh` | Hàm dùng chung: bật/tắt agent, chờ cổng, lệnh HBase, sinh conf theo tham số |
| `run_batch.sh`, `run_stream.sh` | Chạy và kiểm chứng từng kịch bản, ghi log vào `output/` |
| `conf/crash-demo.conf`, `crash_demo.sh` | Thí nghiệm sập agent: 1.000 sự kiện nằm trong channel, `kill -9`, khởi động lại → đếm số sự kiện mỗi channel giao được |
| `test.sh` | Kiểm thử CI (~3 phút): 3 tệp CSV trùng từng byte; 50 sự kiện + 1 sự kiện hỏng + gửi lại 10 → HDFS 61 dòng, HBase 50 dòng |
| `output/batch_run.txt` | Log kịch bản (i) |
| `output/stream_run.txt`, `replay_run1.json`, `replay_run2.json`, `stream_metrics.json` | Log, tóm tắt phát lại và metrics JSON của kịch bản (ii) |
| `output/stream_bench_max.txt` | Đo thông lượng tối đa (5.000 sự kiện không giới hạn nhịp, trên đường dẫn/bảng riêng) |
| `output/crash_demo.txt` | Log thí nghiệm sập agent |

## Kết quả (2026-10-11)

| Kiểm tra | Kết quả |
|---|---|
| (i) 3 tệp CSV trên HDFS so với tệp gốc | trùng md5, cùng số byte (2.298.806 / 62.345 / 20.621) và số dòng (15.001 / 1.201 / 401), còn BOM `ef bb bf`, replication 3 |
| (i) Thời gian | spooldir đọc xong sau 2,06 s; sink đóng tệp sau 39,1 s (phần lớn là `idleTimeout` 30 s) |
| (ii) Lần 1: 5.000 sự kiện, nhịp 250/s, lô 50 | 19,8 s, 252,5 sự kiện/s, 0 lần gửi lại |
| (ii) Lần 2: gửi lại 1.000 sự kiện | HDFS 6.000 dòng, 5.000 `event_id` khác nhau (đúng tập gốc); HBase **5.000** dòng |
| (ii) Metrics | mỗi channel put = take = 6.000, `ChannelSize` 0, 0 lỗi ghi |
| Thông lượng tối đa | 5.000 sự kiện trong 0,61 s ≈ 8.199 sự kiện/s (HTTP source → 2 channel) |
| Sập agent (`kill -9`) với 1.000 sự kiện trong channel | FileChannel giao lại 1.000/1.000; MemoryChannel mất 1.000/1.000 |
| HBase sau flush | 5.000 sự kiện = 387.694 byte HFile (SNAPPY), xem `cau03_hdfs/output/zones_report.txt` |

## Ghi chú thiết kế
- **Tệp lô phải bất biến và có tên không lặp:** spooldir báo lỗi và dừng nếu tệp bị sửa hoặc trùng tên tệp đã nạp. Script chép vào `<tên>.tmp` (bị `ignorePattern` bỏ qua) rồi `mv` (đổi tên nguyên tử).
- **Raw giữ nguyên từng byte:** BOM, dòng tiêu đề và CRLF đi qua Flume không đổi. Bỏ BOM/tiêu đề là việc của Pig (staging), đúng quy ước.
- **Mỗi lô một tệp HDFS:** `filePrefix = %{basename}` nên mỗi tệp lô là một bucket riêng. Tệp đang ghi mang tên `_….tmp`, nên Pig/MapReduce/Spark không đọc nhầm.
- **Sự kiện hỏng:** dòng không khớp regex không được ghi vào HBase, nhưng vẫn nằm nguyên trong HDFS raw (test.sh kiểm chứng).
- **Hạn chế:** regex phụ thuộc thứ tự khóa JSON; rowkey `EVT-ORD…` tăng dần nên sẽ dồn ghi vào một region khi tải lớn. Hướng xử lý xem mục 3.3 của báo cáo.
