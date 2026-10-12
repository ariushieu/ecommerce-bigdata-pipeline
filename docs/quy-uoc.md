# Quy ước chung của nhóm

Mọi câu phải theo các quy ước này để kết quả ghép và đối chiếu được với nhau. Muốn đổi thì báo nhóm trưởng trước.

## 1. Đường dẫn HDFS

| Vùng | Đường dẫn | Nội dung | Ai ghi |
|---|---|---|---|
| raw | `/btl/raw/orders/ingest_date=YYYY-MM-DD/` | `orders.csv` nguyên bản (còn BOM, còn dòng tiêu đề) | `cau03_hdfs/init_zones.sh`, Flume kịch bản (i) |
| raw | `/btl/raw/customers/ingest_date=…/`, `/btl/raw/products/ingest_date=…/` | Danh mục nguyên bản | như trên |
| raw | `/btl/raw/events/ingest_date=YYYY-MM-DD/` | Sự kiện JSON Lines | `init_zones.sh`, Flume kịch bản (ii) |
| staging | `/btl/staging/<bảng>/` | Đã làm sạch, bỏ tiêu đề và BOM, phân tách bằng tab | Pig (Câu 4) |
| curated | `/btl/curated/orders/year=YYYY/month=MM/category=<cat>/` | Parquet đã làm sạch, phân vùng theo thời gian và danh mục | Spark (Câu 6) |
| output | `/btl/output/cau04_pig/`, `/btl/output/cau05_mr/`, `/btl/output/cau06_spark/` | Kết quả tổng hợp của từng công cụ | từng câu |

- **Bản chụp chuẩn để phân tích:** `ingest_date=2026-08-01` (ngày sau bản ghi cuối cùng 31/07/2026). Pig, MapReduce và Spark đều đọc partition này, nên số liệu khớp nhau. Flume ghi thêm các partition theo ngày chạy thật, những partition đó chỉ dùng để minh họa thu thập.
- **Bảng HBase:**
  - `btl:customer_orders` (Câu 7): rowkey `customer_id#reverse_timestamp`, nạp từ `orders`.
  - `btl:order_events` (Câu 2): sự kiện Flume ghi vào. Sự kiện không có `customer_id` nên dùng rowkey riêng.
- Dữ liệu gốc trong container nằm ở `/data` (chỉ đọc).

## 2. Làm sạch dữ liệu

- Bỏ `quality_flag` ∈ {OUTLIER, DUPLICATE, LATE}, giữ MISSING. Sau khi làm sạch còn **14.408 đơn**.
- Bỏ dòng tiêu đề và ký tự BOM khi đọc CSV.
- Ô trống (`review_score`, `campaign_id`; trong SQLite là `''`) chuyển thành NULL/NA, không thay bằng 0.
- Không cộng sự kiện JSON với đơn hàng, vì 5.000 sự kiện trùng với đơn ORD0000001–5000.
- Không tính lợi nhuận từ `unit_cost`/`list_price`, vì giá trong danh mục sản phẩm không nhất quán.
- `province` của đơn là **tỉnh giao hàng**.

## 3. Đầu ra đối chiếu Pig – MapReduce – Spark

Câu 4, 5 và 6 đều xuất thêm file `src/cauXX_*/output/compare_category_month.csv`, tính trên 14.408 đơn sạch, để Câu 10 so sánh từng ô:

```
category,month,orders,net_revenue,returned,return_rate_pct
Beauty,2025-01,118,612345.67,9,7.63
```

- Sắp theo `category`, rồi theo `month` (`YYYY-MM`).
- `net_revenue` làm tròn 2 chữ số; `return_rate_pct = 100 × returned / orders`, làm tròn 2 chữ số.
- Dấu thập phân là `.`, có dòng tiêu đề, xuống dòng LF.

## 4. Viết báo cáo

- Báo cáo theo **Mẫu báo cáo BTL CTKU122**. Mỗi mục của mẫu là một file trong `report/sections/`. Chỉ sửa mục mình phụ trách (xem `report/README.md`).
- **Đánh số bảng/hình bằng nhãn**, để `scripts/build-report.sh` tự đánh số theo chương khi ghép báo cáo:
  - Tên bảng (đặt trên bảng): `*[Bảng:nhan-bang]. Tên bảng*`
  - Tên hình (đặt dưới hình): `*[Hình:nhan-hinh]. Tên hình*`
  - Nhắc tới trong bài: `[Bảng:nhan-bang]`, `[Hình:nhan-hinh]`
  - Nhãn chỉ gồm chữ thường không dấu, số và `-`; không trùng trong toàn báo cáo.
- Sau mỗi bảng/hình phải có đoạn **Nhận xét**.
- Số liệu phải lấy từ output thật của code. Ghi rõ lệnh chạy ra số đó.
- Ảnh chụp màn hình để trong `docs/images/` với tên `cauXX-mo-ta.png`.
- Sơ đồ vẽ bằng khối ` ```mermaid `. Script ghép báo cáo tự đổi thành ảnh.
- Mục có nhiều người viết được tách thành file con, mỗi người một file: `14b…14e` (1.4), `24a`/`24b` (2.4), `32a`/`32b` (3.2), `96b…96e` (Phụ lục B).
- Tài liệu tham khảo (chuẩn IEEE) và từ viết tắt mới **không sửa trực tiếp** `90-…`/`01-…`. Ghi vào `report/contrib/<thành viên>.md`, nhóm trưởng gộp và đánh số tham khảo chung, để tránh xung đột khi nhiều người sửa cùng lúc. Trong bài trích dẫn bằng nhãn `[TL:ten-nhan]`. Không ghi chung chung Google/Wikipedia/công cụ AI.

## 5. Một câu được coi là xong khi

1. Code chạy được trên cụm (`ssh may1`), có `README.md` ghi lệnh chạy.
2. Có `test.sh` (CI tự chạy), kiểm tra ít nhất các con số chính.
3. Kết quả nhỏ (CSV tổng hợp, log thời gian chạy) đã commit trong `output/`.
4. Các mục báo cáo mình phụ trách đã viết xong và dùng số liệu từ `output/`.
5. Có 1–3 ảnh minh chứng trong `docs/images/`.
