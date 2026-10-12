# Câu 1 – Số liệu profiling (sinh tự động bởi `profile_data.py`)

## Volume

| Tệp | Byte | Bản ghi | Cột | Byte/bản ghi |
|---|---|---|---|---|
| orders.csv | 2.298.806 | 15.000 | 23 | 153,3 |
| customers.csv | 62.345 | 1.200 | 8 | 52 |
| products.csv | 20.621 | 400 | 8 | 51,6 |
| events_stream.jsonl | 1.118.573 | 5.000 | – | 223,7 |
| project_data.sqlite | 3.506.176 | 16.600 | – | 211,2 |
| data_dictionary.csv | 2.821 | 39 | 6 | 72,3 |

- Tổng: **7.009.342 byte**; trên HDFS replication 3: **21.028.026 byte**.
- SQLite: `entity_master` 1.200 dòng, `fact_main` 15.000 dòng, `item_master` 400 dòng.
- Khoảng thời gian đơn hàng: 2025-01-01T00:33:37 → 2026-07-31T23:39:49 (577 ngày), trung bình **26 đơn/ngày**, ≈ 3.984 byte CSV/ngày.

## Velocity

| Tháng | Đơn |
|---|---|
| 2025-01 | 830 |
| 2025-02 | 747 |
| 2025-03 | 871 |
| 2025-04 | 783 |
| 2025-05 | 803 |
| 2025-06 | 781 |
| 2025-07 | 766 |
| 2025-08 | 800 |
| 2025-09 | 770 |
| 2025-10 | 795 |
| 2025-11 | 803 |
| 2025-12 | 821 |
| 2026-01 | 799 |
| 2026-02 | 693 |
| 2026-03 | 790 |
| 2026-04 | 792 |
| 2026-05 | 769 |
| 2026-06 | 781 |
| 2026-07 | 806 |

- Đơn/ngày: trung bình 26, cao nhất 39 (ngày 2025-01-10); tối đa 8 đơn trong một giờ.
- Giờ cao điểm trong ngày: 23h (670 đơn cộng dồn).
- `ingest_mode`: stream 9.297, batch 5.703.
- `events_stream.jsonl`: 5.000 sự kiện trải 577 ngày; **50,27%** cặp liên tiếp bị ngược thời gian; độ lệch vị trí trung vị 1.495, tối đa 4.962 bản ghi.

## Variety

- Mã hóa: `orders.csv` UTF-8 BOM, `customers.csv` UTF-8 BOM, `products.csv` UTF-8 BOM, `events_stream.jsonl` UTF-8, `data_dictionary.csv` UTF-8 BOM.
- Nhãn `data_format`: JSON 5.010, LOG 5.041, CSV 4.949.
- `source_system`: mobile 3.020, partner 3.002, web 3.001, api 2.899, batch 3.078.
- Khóa JSON cấp 1: event_id, event_time, event_type, source, payload; `payload`: category, customer_segment, net_revenue, returned_flag.

### `orders.csv`

| Cột | Kiểu suy ra | Null | % null | Giá trị khác nhau |
|---|---|---|---|---|
| record_id | string | 0 | 0 | 15.000 |
| timestamp | datetime | 0 | 0 | 15.000 |
| province | string | 0 | 0 | 18 |
| source_system | string | 0 | 0 | 5 |
| ingest_mode | string | 0 | 0 | 2 |
| data_format | string | 0 | 0 | 3 |
| order_id | string | 0 | 0 | 15.000 |
| customer_id | string | 0 | 0 | 1.200 |
| product_id | string | 0 | 0 | 400 |
| category | string | 0 | 0 | 6 |
| customer_segment | string | 0 | 0 | 4 |
| sales_channel | string | 0 | 0 | 3 |
| quantity | int | 0 | 0 | 6 |
| unit_price | float | 0 | 0 | 10.326 |
| discount_rate | float | 0 | 0 | 6 |
| shipping_fee | float | 0 | 0 | 5 |
| net_revenue | float | 0 | 0 | 14.430 |
| payment_method | string | 0 | 0 | 4 |
| delivery_days | float | 0 | 0 | 82 |
| returned_flag | int | 0 | 0 | 2 |
| review_score | int | 5.390 | 35,93 | 6 |
| campaign_id | string | 165 | 1,1 | 31 |
| quality_flag | string | 0 | 0 | 5 |

### `customers.csv`

| Cột | Kiểu suy ra | Null | % null | Giá trị khác nhau |
|---|---|---|---|---|
| customer_id | string | 0 | 0 | 1.200 |
| customer_segment | string | 0 | 0 | 4 |
| age_group | string | 0 | 0 | 5 |
| gender | string | 0 | 0 | 3 |
| province | string | 0 | 0 | 18 |
| join_date | date | 0 | 0 | 837 |
| loyalty_score | int | 0 | 0 | 101 |
| preferred_channel | string | 0 | 0 | 2 |

### `products.csv`

| Cột | Kiểu suy ra | Null | % null | Giá trị khác nhau |
|---|---|---|---|---|
| product_id | string | 0 | 0 | 400 |
| category | string | 0 | 0 | 6 |
| brand | string | 0 | 0 | 44 |
| unit_cost | float | 0 | 0 | 400 |
| list_price | float | 0 | 0 | 400 |
| supplier_id | string | 0 | 0 | 79 |
| rating | float | 0 | 0 | 26 |
| active_flag | int | 0 | 0 | 2 |

### `events_stream.jsonl`

| Cột | Kiểu suy ra | Null | % null | Giá trị khác nhau |
|---|---|---|---|---|
| event_id | string | 0 | 0 | 5.000 |
| event_time | datetime | 0 | 0 | 5.000 |
| event_type | string | 0 | 0 | 1 |
| source | string | 0 | 0 | 5 |
| payload.category | string | 0 | 0 | 6 |
| payload.customer_segment | string | 0 | 0 | 4 |
| payload.net_revenue | float | 0 | 0 | 4.934 |
| payload.returned_flag | int | 0 | 0 | 2 |

## Veracity

| quality_flag | Bản ghi | % | Sai công thức net_revenue | delivery_days lẻ | delivery_days max | review_score null | campaign_id null |
|---|---|---|---|---|---|---|---|
| OK | 14.095 | 93,97 | 0 | 0 | 9 | 4.983 | 0 |
| MISSING | 313 | 2,09 | 0 | 0 | 7 | 210 | 165 |
| OUTLIER | 297 | 1,98 | 219 | 71 | 37,22 | 103 | 0 |
| LATE | 146 | 0,97 | 0 | 0 | 7 | 47 | 0 |
| DUPLICATE | 149 | 0,99 | 0 | 0 | 7 | 47 | 0 |

- Miền giá trị: `quantity<=0` 0, `unit_price<=0` 0, `discount_rate_not_in_[0,1)` 0, `delivery_days<0` 0, `review_score_not_in_[1,5]` 0, `returned_flag_not_0_1` 0.
- Toàn vẹn: `duplicate_record_id` 0, `duplicate_order_id` 0, `record_id_ne_order_id` 0, `orphan_customer_id` 0, `orphan_product_id` 0, `category_ne_product_master` 0, `segment_ne_customer_master` 0, `province_ne_customer_home` 14.166, `inactive_product_orders` 517, `duplicate_content_among_DUPLICATE` 0, `products_list_price_lt_unit_cost` 117, `products_list_over_cost_min` 0,03, `products_list_over_cost_max` 127,69.
- Sự kiện so với đơn gốc (ORD0000001..ORD0005000): khớp 100%.
- SQLite `fact_main`: 15.000 dòng, 0 dòng khác `orders.csv`.
- Quy tắc làm sạch chung (bỏ OUTLIER/DUPLICATE/LATE): còn **14.408** đơn, bỏ 592.

## Value (trên dữ liệu đã làm sạch)

- Doanh thu ròng: **78.218.341,22**, trung bình 5.428,81/đơn.
- Trả hàng: 1.114 đơn (**7,73%**), doanh thu bị trả: 5.965.840,89.
- Giao hàng: trung bình 3,04 ngày, P90 = 5 ngày; 7,01% đơn > 5 ngày.

| Danh mục | Đơn | Doanh thu | % trả | Ngày giao TB |
|---|---|---|---|---|
| Books | 2.953 | 15.741.983,83 | 7,59 | 2,99 |
| Home | 2.616 | 14.257.300,58 | 7,49 | 3,05 |
| Electronics | 2.505 | 14.086.726,93 | 7,54 | 3,06 |
| Sports | 2.280 | 12.994.254,03 | 7,89 | 2,97 |
| Beauty | 2.219 | 11.426.625,74 | 7,62 | 3,11 |
| Fashion | 1.835 | 9.711.450,11 | 8,5 | 3,09 |

| Ngày giao | Đơn | % trả |
|---|---|---|
| 0 | 1.002 | 8,38 |
| 1 | 1.608 | 6,47 |
| 2 | 2.889 | 8,34 |
| 3 | 3.315 | 8,02 |
| 4 | 2.836 | 6,84 |
| 5 | 1.748 | 8,35 |
| 6 | 746 | 8,18 |
| 7+ | 264 | 6,82 |
