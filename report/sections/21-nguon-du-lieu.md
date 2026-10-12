## 2.1. Nguồn và mô tả dữ liệu

Dữ liệu do giảng viên cung cấp kèm Đề 01. Đây là dữ liệu giả lập phục vụ học tập, không chứa thông tin cá nhân thật, mô phỏng hoạt động của một sàn thương mại điện tử từ 01/01/2025 đến 31/07/2026.

*[Bảng:mo-ta-tep]. Mô tả và phân loại các tệp dữ liệu*

| Tệp | Định dạng | Số bản ghi | Số thuộc tính | Dung lượng | Phạm vi | Loại dữ liệu |
|---|---|---:|---:|---:|---|---|
| `orders.csv` | CSV, UTF-8 có BOM | 15.000 | 23 | 2,30 MB | Đơn hàng 01/01/2025 – 31/07/2026 | Có cấu trúc |
| `events_stream.jsonl` | JSON Lines | 5.000 | 4 + 4 trong `payload` | 1,12 MB | Sự kiện `order_event` của đơn ORD0000001 – ORD0005000 | Bán cấu trúc; dữ liệu luồng |
| `customers.csv` | CSV, UTF-8 có BOM | 1.200 | 8 | 0,06 MB | Khách tham gia 25/11/2020 – 31/12/2024 | Có cấu trúc (danh mục) |
| `products.csv` | CSV, UTF-8 có BOM | 400 | 8 | 0,02 MB | 6 danh mục, 44 thương hiệu, 79 nhà cung cấp | Có cấu trúc (danh mục) |
| `project_data.sqlite` | SQLite 3 | 16.600 | 23 / 8 / 8 | 3,51 MB | `fact_main`, `entity_master`, `item_master` | Có cấu trúc (quan hệ) |
| `data_dictionary.csv` | CSV, UTF-8 có BOM | 39 | 6 | 0,003 MB | Mô tả 39 cột của 3 bảng | Có cấu trúc (siêu dữ liệu) |

**Nhận xét [Bảng:mo-ta-tep]:**
- **Dữ liệu có cấu trúc:** các tệp CSV và SQLite có lược đồ cố định, mỗi dòng có cùng số cột và cùng ý nghĩa cột.
- **Dữ liệu bán cấu trúc:** `events_stream.jsonl` tự mô tả bằng tên khóa, có đối tượng lồng nhau (`payload`), lược đồ chỉ xác định khi đọc.
- **Dữ liệu luồng:** `events_stream.jsonl` cũng là dữ liệu luồng, vì mỗi dòng là một sự kiện độc lập có thời điểm phát sinh, được nối thêm liên tục và đến không theo thứ tự.
- Phân loại *có cấu trúc / bán cấu trúc* nói về **hình dạng** bản ghi, còn *luồng* nói về **cách dữ liệu đến**. Một tệp có thể thuộc cả hai, như `events_stream.jsonl`.
- 9.297 dòng `ingest_mode = stream` trong `orders.csv` có nguồn gốc từ luồng, nhưng tệp CSV là **ảnh chụp theo lô** đã làm phẳng thành bảng, nên vẫn xếp vào nhóm có cấu trúc.
- Bảng `fact_main` trong SQLite trùng khớp hoàn toàn với `orders.csv` (0/15.000 dòng khác biệt).

