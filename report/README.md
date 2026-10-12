# Báo cáo

Báo cáo viết theo **Mẫu báo cáo BTL CTKU122** (chia theo chương, không chia theo câu). Mỗi mục của mẫu là một file trong `sections/`, đánh số để ghép đúng thứ tự, nên 5 người viết song song không bị xung đột.

```bash
bash scripts/build-report.sh     # chạy trên máy thật (Git Bash), cần Docker → report/build/BaoCao.docx
```

Script này ghép các mục, đánh số bảng/hình theo chương và vẽ sơ đồ mermaid thành ảnh. Riêng trang bìa, phiếu đánh giá và tổng hợp điểm thì chép tay từ file mẫu của bộ môn ở bước cuối.

## Mục – người phụ trách

| File | Mục | Phụ trách |
|---|---|---|
| `00-phan-cong.md` | Phân công nhiệm vụ | A |
| `01-tu-viet-tat.md` | Danh mục từ viết tắt | mọi người bổ sung |
| `02-loi-mo-dau.md` | Lời mở đầu | A |
| `11`, `12` | 1.1 Giới thiệu bài toán, 1.2 Mục tiêu | A (Câu 10) |
| `13-dac-trung-big-data.md` | 1.3 Đặc trưng Big Data | A (Câu 1) ✅ |
| `14-cong-nghe.md` + `14b`…`14e` | 1.4 Công nghệ sử dụng | A (mở đầu) + B, C, D, E mỗi người một file |
| `15-kien-truc-tong-the.md` | 1.5 Kiến trúc tổng thể | B (Câu 2) |
| `21`, `22`, `23` | 2.1 Nguồn dữ liệu, 2.2 Thuộc tính, 2.3 Chất lượng | A (Câu 1) ✅ |
| `24-lam-sach-bien-doi.md` + `24a`, `24b` | 2.4 Làm sạch và biến đổi | C (`24a`, Pig) + D (`24b`, Spark) |
| `25-ket-qua-tien-xu-ly.md` | 2.5 Kết quả sau tiền xử lý | D |
| `31-moi-truong.md` | 3.1 Môi trường triển khai | A |
| `32-to-chuc-luu-tru.md` + `32a`, `32b` | 3.2 Tổ chức lưu trữ | B (`32a`, HDFS) + D (`32b`, HBase) |
| `33-pipeline.md` | 3.3 Pipeline xử lý | B |
| `34-spark.md` | 3.4 Spark | D |
| `35-thuat-toan-chuyen-biet.md` | 3.5 MapReduce, Pig | C |
| `36-luu-xuat-ket-qua.md` | 3.6 Lưu và xuất kết quả | D |
| `41-ket-qua-xu-ly.md` | 4.1 Kết quả xử lý | C |
| `42-ket-qua-phan-tich.md` | 4.2 Kết quả phân tích | E |
| `43-truc-quan-hoa.md` | 4.3 Trực quan hóa | E |
| `44-hieu-nang.md` | 4.4 Đánh giá hiệu năng | D |
| `45-thao-luan.md` | 4.5 Thảo luận | A (Câu 10) |
| `51`–`53` | Chương 5 | A (Câu 10) |
| `90-tai-lieu-tham-khao.md` | Tài liệu tham khảo | A gộp từ `report/contrib/*.md` |
| `95`–`97` | Phụ lục A (A); B (`96b`…`96e`, mỗi người); C (E) | |

Câu 1 nằm ở mục 1.3 và 2.1–2.3; Câu 10 nằm ở các mục còn lại của A. Cách đánh số bảng/hình bằng nhãn và các quy định khác: [`docs/quy-uoc.md`](../docs/quy-uoc.md) mục 4.

Ảnh dùng chung để trong `docs/images/`.
