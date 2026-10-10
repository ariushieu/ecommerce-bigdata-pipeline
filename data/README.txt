ĐỀ 01: Phân tích hành vi mua sắm và vận hành thương mại điện tử

Dữ liệu giả lập phục vụ học tập, không chứa dữ liệu cá nhân thật.
- orders.csv: 15,000 bản ghi, 23 cột, UTF-8 BOM, thời gian ISO 8601.
- customers.csv: 1,200 bản ghi danh mục.
- products.csv: 400 bản ghi danh mục.
- events_stream.jsonl: 5,000 sự kiện JSON Lines mô phỏng luồng.
- project_data.sqlite: CSDL SQLite gồm fact_main, entity_master, item_master.
- data_dictionary.csv: từ điển dữ liệu.

Lưu ý chất lượng: cột quality_flag đánh dấu một tỷ lệ nhỏ bản ghi MISSING/OUTLIER/LATE/DUPLICATE có chủ đích để thực hành làm sạch; định dạng và khóa liên kết vẫn được chuẩn hóa.
