# Câu 10 – Đối chiếu Pig – MapReduce – Spark

**Yêu cầu:** tích hợp thành báo cáo kỹ thuật hoàn chỉnh, trong đó có **đối chiếu Pig – MapReduce – Spark**. Thư mục này chứa phần đối chiếu có thể chạy lại. Các mục báo cáo của Câu 10 là Lời mở đầu, 1.1, 1.2, 4.5, Chương 5 và Phụ lục A (`report/sections/`).

**Phụ trách:** Nguyễn Quốc Hiếu – thành viên A, nhóm trưởng (xem [phân công](../../README.md#phân-công-mỗi-người-20)). Quy ước chung: [`docs/quy-uoc.md`](../../docs/quy-uoc.md).

**Chạy (trong `ssh may1`, thư mục `~/src`):**

```bash
cd cau10_doi_chieu
python3 compare.py           # so từng ô 3 tệp compare_category_month.csv (Câu 4, 5, 6) + tổng Câu 1
bash bench.sh 3              # đo cùng phép tính bằng 3 công cụ, 3 lần, quy mô x1 và x10 (khoảng 15 phút, cụm phải rảnh)
bash test.sh                 # CI chạy: khớp từng ô, cú pháp Pig/Python
```

| Tệp | Nội dung |
|---|---|
| `compare.py` | Đối chiếu kết quả; ghi `output/doi_chieu.md`, thoát lỗi nếu có ô sai khác |
| `category_month.pig` | Bản Pig tối giản của phép tính danh mục × tháng (19 dòng) |
| `spark_category_month.py` | Bản Spark tối giản, dùng lại hàm đọc/làm sạch của Câu 6 |
| `bench.sh` | Chạy MapReduce (job `category_month` của Câu 5), Pig, Spark; ghi `output/bench.tsv`, `output/bench_avg.tsv` |

## Kết quả

- 114 ô danh mục × tháng của ba công cụ **trùng nhau từng byte**; tổng = 14.408 đơn, 78.218.341,22, 1.114 đơn trả (= Câu 1).
- Thời gian (trung vị 3 lần, cụm rảnh):
  - MapReduce: 18,1 s ở ×1, 16,3 s ở ×10;
  - Spark: 19,5 s ở ×1, 17,6 s ở ×10;
  - Pig: 64,1 s ở ×1, 54,1 s ở ×10 (`ORDER` sinh 3 job).

  Ở quy mô này, chi phí khởi động job chiếm gần hết thời gian. Phân tích đầy đủ ở mục 4.5 của báo cáo.
