## 1.5. Kiến trúc tổng thể hệ thống

Hệ thống theo kiến trúc Lambda [TL:marz2015], cụ thể hóa sơ đồ phân luồng ở [Hình:phan-luong-xu-ly]: lớp lô xử lý toàn bộ lịch sử trên HDFS, lớp tốc độ đưa sự kiện mới vào HBase để tra cứu ngay. Kiến trúc gồm năm tầng ([Hình:c02-kien-truc-tong-the]); YARN cấp tài nguyên cho mọi job của tầng xử lý.

```mermaid
flowchart LR
  subgraph NGUON["Tầng 1: Nguồn dữ liệu"]
    direction TB
    CSV["orders.csv<br/>customers.csv, products.csv<br/>(theo lô)"]
    EV["order_event<br/>(luồng)"]
    SQ[("project_data.sqlite")]
  end
  subgraph THU["Tầng 2: Thu thập bằng Flume"]
    direction TB
    B1["Agent b1: spooldir<br/>→ FileChannel → HDFS"]
    S1["Agent s1: HTTP<br/>FileChannel → HDFS<br/>MemoryChannel → HBase"]
  end
  subgraph THO["Tầng 3a: Lưu trữ thô"]
    direction TB
    RAW[("HDFS raw ×3")]
    HBE[("HBase<br/>btl:order_events")]
  end
  subgraph XL["Tầng 4: Xử lý trên YARN"]
    direction TB
    PIG["Pig (Câu 4)"]
    MR["MapReduce (Câu 5)"]
    SP["Spark (Câu 6)"]
    LD["Trình nạp HBase (Câu 7)"]
  end
  subgraph DXL["Tầng 3b: Lưu kết quả"]
    direction TB
    STG[("HDFS staging, curated,<br/>output ×3")]
    HBC[("HBase<br/>btl:customer_orders")]
  end
  subgraph PV["Tầng 5: Phân tích và phục vụ"]
    direction TB
    BS["BigSheets / dashboard (Câu 8)"]
    RR["R: SQL, mô hình (Câu 9)"]
    TC["Tra cứu gần thời gian thực"]
    BC["Báo cáo, khuyến nghị (Câu 10)"]
  end
  CSV --> B1
  CSV -.->|"bản chụp 2026-08-01"| RAW
  B1 --> RAW
  EV -->|"POST JSON"| S1
  S1 --> RAW
  S1 --> HBE
  RAW --> PIG & MR & SP & LD
  PIG & MR & SP --> STG
  LD --> HBC
  STG --> BS
  SQ --> RR
  HBE --> TC
  HBC --> TC
  STG --> BC
  BS --> BC
  RR --> BC
```

*[Hình:c02-kien-truc-tong-the]. Kiến trúc thu thập, lưu trữ và xử lý dữ liệu đầu–cuối*

**Nhận xét [Hình:c02-kien-truc-tong-the]:**
- **Hai đường vào tách biệt** (`b1` cho lô, `s1` cho luồng); mỗi sự kiện được ghi cả vào HDFS (bền vững) và HBase (độ trễ thấp), chi tiết ở mục 3.3.
- **Raw là nguồn sự thật duy nhất:** mọi công cụ đọc cùng bản chụp `ingest_date=2026-08-01`, nên kết quả đối chiếu được và HBase hay curated hỏng vẫn tính lại được.
- SQLite là nguồn riêng của Câu 9, phân tích bằng R; không có IBM BigInsights nên BigSheets (Câu 8) được mô phỏng bằng R.

*[Bảng:c02-tang-kien-truc]. Các tầng của kiến trúc và thành phần đảm nhận*

| Tầng | Thành phần | Cơ chế chịu lỗi | Câu |
|---|---|---|---|
| 1. Nguồn | Tệp CSV, luồng `order_event`, SQLite | – | 1 |
| 2. Thu thập | Flume `b1` (spooldir), `s1` (HTTP) | Giao dịch, FileChannel ghi đĩa, client gửi lại khi nhận HTTP 503 | 2 |
| 3. Lưu trữ | HDFS 4 vùng; HBase 2 bảng | Nhân bản 3; WAL, gán lại region | 3, 7 |
| 4. Xử lý | Pig, MapReduce, Spark, trình nạp HBase trên YARN | YARN chạy lại container/task lỗi; Spark tính lại từ lineage | 4–7 |
| 5. Phân tích, phục vụ | BigSheets/R dashboard, R, tra cứu HBase | Tạo lại được từ các vùng dưới | 8–10 |

**Nhận xét [Bảng:c02-tang-kien-truc]:**
- Mỗi tầng chỉ phụ thuộc tầng dưới qua **giao diện cố định** (đường dẫn HDFS, tên bảng HBase đã chốt), nên năm thành viên làm song song và có thể thay một công cụ mà không sửa tầng khác.
- Khả năng chịu lỗi có ở mọi tầng; điểm yếu còn lại là **NameNode và HMaster chỉ có một bản** (mục 3.2.1).
