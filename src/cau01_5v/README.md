# Câu 1 – Profiling dữ liệu cho phân tích 5V

**Yêu cầu:** Phân tích đặc trưng Big Data theo tối thiểu 5V; phân loại tệp và trường thành có cấu trúc / bán cấu trúc / luồng; chỉ rõ phần phân tích tĩnh và phần cần xử lý gần thời gian thực.

**Bài viết:** mục 1.3, 2.1, 2.2, 2.3 của báo cáo – [`report/sections/13-*.md`, `21-*.md`, `22-*.md`, `23-*.md`](../../report/sections/). Thư mục này chứa script sinh số liệu làm căn cứ cho bài viết.

**Phụ trách:** Nguyễn Quốc Hiếu – thành viên A, nhóm trưởng (xem [phân công](../../README.md#phân-công-mỗi-người-20)). Quy ước chung: [`docs/quy-uoc.md`](../../docs/quy-uoc.md).

**Chạy (trong `ssh may1`, thư mục `~/src`):**

```bash
cd cau01_5v
python3 profile_data.py      # ghi output/profile.json + output/profile.md
bash test.sh                 # chạy lại, so với output/ đã commit + kiểm tra bất biến
```

| Tệp | Nội dung |
|---|---|
| `profile_data.py` | Đọc `/data` (chỉ thư viện chuẩn Python 3.8), tính số liệu Volume, Velocity, Variety, Veracity, Value |
| `output/profile.json` | Số liệu thô |
| `output/profile.md` | Bảng tóm tắt, bài viết trích số từ đây |
| `test.sh` | CI chạy ở mỗi lần push: báo lỗi nếu `output/` cũ hoặc dữ liệu đổi bất biến |

Nếu dữ liệu hoặc script thay đổi, chạy lại `profile_data.py`, commit `output/`, rồi cập nhật số trong các mục báo cáo trên.

## Lưu ý cho các câu sau

| Phát hiện | Áp dụng ở câu |
|---|---|
| Làm sạch theo `quality_flag`, không dùng `DISTINCT`; giữ MISSING | 4, 5, 6, 9 |
| Xử lý BOM khi đọc CSV | 2, 4, 5, 6, 8, 9 |
| SQLite lưu ô trống là `''` | 9 |
| `province` là tỉnh giao hàng | 5, 8, 9 |
| Không cộng sự kiện với đơn hàng (trùng doanh thu ORD0000001–5000) | 2, 6, 10 |
| Danh mục nhỏ: dùng replicated/broadcast join | 4, 6 |
| Không tính lợi nhuận từ `unit_cost`/`list_price` | 6, 9, 10 |
| Tín hiệu trả hàng yếu: báo cáo đúng mức, không thổi phồng | 9, 10 |
| Dữ liệu nhỏ: chênh lệch thời gian Pig/MR/Spark chủ yếu do chi phí khởi động job | 6, 10 (mục 4.4) |
