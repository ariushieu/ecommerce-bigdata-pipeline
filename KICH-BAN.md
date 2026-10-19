# Kịch bản trình bày và demo – Đề 01

Mỗi người nói phần của mình theo thứ tự dưới đây. Dòng **▶ Làm** là thao tác trên máy; phần trong khung trích dẫn là lời nói. Lời nói chỉ là gợi ý, nói tự nhiên bằng lời của mình, miễn đủ ý và đúng số liệu. Lệnh và trang web của từng câu: [DEMO.md](DEMO.md).

Tổng thời gian khoảng 25 phút, chưa kể phần hỏi đáp. Nếu cô cho ít thời gian hơn, chạy các script với `nhanh` và bỏ các đoạn đánh dấu *(có thể bỏ)*.

**Trước khi lên:** cụm đã bật, smoke-test 8 PASS; tab thứ hai (`ssh may1`) đang chạy sẵn `bash ~/src/demo/cau04.sh`; trình duyệt mở sẵn 6 trang web; báo cáo in để trên bàn.

---

## Phần 1. Mở đầu – Nguyễn Quốc Hiếu (nhóm trưởng), 3 phút

> Em chào cô. Em là Nguyễn Quốc Hiếu, nhóm trưởng. Nhóm em gồm 5 thành viên: Nguyễn Trần Khánh Duy, Nguyễn Tiến Hiệp, Vũ Văn Quốc, Phạm Văn Quyết và em. Nhóm em làm **Đề 01: Phân tích hành vi mua sắm và vận hành thương mại điện tử**.
>
> Bài toán là một sàn thương mại điện tử bán trên ba kênh web, ứng dụng di động và marketplace, cho khách ở 18 tỉnh, với 400 sản phẩm thuộc 6 nhóm hàng. Sàn có hai loại dữ liệu: dữ liệu theo lô, gồm đơn hàng, khách hàng, sản phẩm; và dữ liệu luồng, là các sự kiện đơn hàng gửi liên tục. Dữ liệu nằm rời rạc ở nhiều định dạng và có bản ghi lỗi, nên sàn chưa trả lời nhanh được ba câu hỏi: **doanh thu cao ở đâu, hoàn trả cao ở đâu, giao hàng mất bao lâu**.
>
> Mục tiêu của nhóm em là xây một nền tảng phân tích dữ liệu lớn: thu thập cả lô và luồng, lưu trữ phân tán, làm sạch theo một quy tắc thống nhất, xử lý bằng Pig, MapReduce, Spark và HBase, rồi phân tích bằng R để đưa ra khuyến nghị cho ba mục tiêu: **tăng doanh thu, giảm hoàn trả, rút ngắn thời gian giao**.

**▶ Làm:** mở báo cáo tới Hình kiến trúc tổng thể (mục 1.5).

> Đây là kiến trúc tổng thể, gồm 5 tầng: nguồn, thu thập bằng Flume, lưu trữ trên HDFS và HBase, xử lý bằng Pig, MapReduce, Spark, và cuối cùng là phân tích, trực quan hóa. Hệ thống chạy trên một cụm Hadoop 4 node: một master và ba worker. Mỗi bạn trong nhóm phụ trách hai câu, đúng như bảng phân công ở đầu báo cáo. Em xin trình bày Câu 1 trước.

---

## Phần 2. Câu 1 – Hiếu, 2 phút

**▶ Làm:** tab `may1`, chạy `bash ~/src/demo/cau01.sh`, bấm Enter qua từng bước.

> Câu 1 là phân tích đặc trưng Big Data của bộ dữ liệu. Script này đọc trực tiếp các tệp gốc của đề để đo số liệu thật, không phải gõ tay.

**▶ Khi hiện bảng Volume:**

> **Volume:** 6 tệp, tổng khoảng 7 MB; trên HDFS nhân bản 3 lần là khoảng 21 MB. Đây là mẫu thu nhỏ; nhóm em đã ước tính một sàn thật ở quy mô này sẽ khoảng 169 GB mỗi năm, trình bày ở Bảng 1.4.
>
> **Variety:** 3 định dạng: CSV, JSON Lines và SQLite. **Velocity:** dữ liệu đến liên tục, hơn một nửa sự kiện, 50,27%, đến sai thứ tự thời gian.

**▶ Khi hiện bảng Veracity:**

> **Veracity:** khoảng 6% bản ghi bị gắn cờ lỗi: OUTLIER, DUPLICATE, LATE và MISSING. Nhóm thống nhất một quy tắc làm sạch dùng chung cho mọi công cụ: bỏ OUTLIER, DUPLICATE, LATE, giữ MISSING. Sau làm sạch còn **14.408 đơn**.

**▶ Khi hiện khung XONG:**

> **Value:** doanh thu ròng 78,2 triệu, tỷ lệ trả 7,73%, thời gian giao trung bình 3,04 ngày. Ba con số này là mốc để các câu sau đối chiếu. Em mời bạn Duy trình bày phần thu thập và lưu trữ.

---

## Phần 3. Câu 2, 3 – Nguyễn Trần Khánh Duy, 5 phút

**▶ Làm:** tab `may1`, chạy `bash ~/src/demo/cau02.sh`.

> Em là Duy, em phụ trách Câu 2 và Câu 3. Câu 2 là thu thập dữ liệu bằng Flume, với hai kịch bản.

**▶ Khi hiện cấu hình:**

> Kịch bản thứ nhất là theo lô: agent `b1` theo dõi một thư mục, có tệp CSV mới là đọc và ghi vào vùng raw trên HDFS. Đọc xong, tệp chỉ được đổi tên thành `.COMPLETED`, không bị xóa, để nạp lại được khi cần. Kịch bản thứ hai là theo luồng: agent `s1` nhận sự kiện qua HTTP, rồi ghi đồng thời vào HDFS để lưu lâu dài và vào HBase để tra cứu nhanh.

**▶ Khi chạy kịch bản luồng:**

> Bây giờ em gửi 5.000 sự kiện, sau đó gửi lại 1.000 sự kiện đầu để mô phỏng lỗi mạng khiến client phải gửi lại. Kết quả: HDFS nhận 6.000 dòng, tức là nhận ít nhất một lần, không mất sự kiện nào. HBase vẫn đúng 5.000 dòng, vì rowkey là `event_id`, gửi lại chỉ ghi đè đúng ô cũ.

**▶ Khi chạy thí nghiệm kill agent:**

> Thí nghiệm cuối: em tắt đột ngột agent bằng `kill -9`, giống như mất điện. Kênh FileChannel ghi xuống đĩa nên giữ đủ **1.000 trên 1.000** sự kiện, còn MemoryChannel giữ trong RAM nên **mất cả 1.000**. Vì vậy dữ liệu quan trọng nhóm em dùng FileChannel.

**▶ Làm:** Ctrl + click link `localhost:16010` trong khung XONG → Tables → `btl:order_events`.

> Đây là bảng sự kiện trên HBase vừa được ghi vào.

**▶ Làm:** chạy `bash ~/src/demo/cau03.sh`.

> Câu 3 là tổ chức lưu trữ trên HDFS. Nhóm em chia 4 vùng: **raw** giữ dữ liệu gốc nguyên vẹn, **staging** là dữ liệu đã làm sạch, **curated** là dữ liệu đã chuẩn hóa dạng Parquet chia phân vùng, và **output** là kết quả phân tích. Mỗi tệp được nhân bản 3 lần, nên 6,9 MB dữ liệu raw chiếm 20,7 MB. Ở đây có thể thấy block của tệp `orders.csv` nằm trên cả 3 DataNode.

**▶ Làm:** mở `localhost:9870` → Datanodes.

> Trên giao diện NameNode có 3 DataNode đang hoạt động.

**▶ Khi hiện kết quả tắt node:**

> Để kiểm tra khả năng chịu lỗi, nhóm em tắt DataNode trên `datanode3`. Đọc lại tệp ngay lập tức vẫn đúng, mã md5 khớp. Sau khoảng 143 giây, NameNode đánh dấu node đó đã chết, rồi tự nhân bản lại các block bị thiếu sang hai node còn lại; đến giây 181 thì đủ bản sao. Bật lại node, HDFS trở về trạng thái HEALTHY.

*(Nếu cô muốn xem trực tiếp: chạy `bash ~/src/demo/cau03_hong_node.sh` (4 phút). Trong lúc chờ, bấm F5 trang Datanodes để thấy `datanode3` chuyển sang Dead.)*

> Em mời bạn Hiệp trình bày phần xử lý bằng Pig và MapReduce.

---

## Phần 4. Câu 4, 5 – Nguyễn Tiến Hiệp, 5 phút

**▶ Làm:** chuyển sang tab thứ hai (Câu 4 đã chạy từ đầu buổi). Nếu chưa xong, nói phần giới thiệu trước.

> Em là Hiệp, em phụ trách Câu 4 và Câu 5. Câu 4 dùng Pig Latin để làm sạch và tổng hợp dữ liệu.

**▶ Khi hiện các bước trong `cau04.pig`:**

> Script gồm các bước: LOAD với khai báo schema; FILTER bỏ dòng tiêu đề và dòng hỏng; SPLIT tách đơn sạch và đơn bị loại; FOREACH chuẩn hóa rồi STORE vào vùng staging; JOIN với bảng khách hàng và sản phẩm theo kiểu replicated, vì hai bảng này nhỏ nên nạp thẳng vào bộ nhớ; rồi GROUP, ORDER để tổng hợp.

**▶ Khi hiện bảng `checks`:**

> Kết quả: 15.000 đơn gốc còn 14.408 đơn sạch, 592 đơn bị loại. Con số này khớp đúng với Câu 1.

**▶ Làm:** mở `localhost:19888`.

> Pig không tự chạy mà dịch script thành **17 job MapReduce**, đây là danh sách các job đó. Vì mỗi job tốn thời gian khởi động nên Pig chạy chậm hơn MapReduce viết tay.

**▶ Làm:** quay lại tab `may1`, chạy `bash ~/src/demo/cau05.sh`.

> Câu 5 là MapReduce viết bằng Java. Mapper đọc và lọc từng đơn, phát ra khóa là danh mục, tỉnh, tháng; Combiner cộng dồn ngay ở phía map; Partitioner tự viết chia 6 danh mục cho 3 reducer; Reducer tính tổng và tỷ lệ trả.

**▶ Khi hiện bộ đếm Combiner:**

> Đây là tác dụng của Combiner: 14.408 bản ghi chỉ còn 2.049 bản ghi phải truyền qua mạng, **giảm 85,8%**, và dung lượng shuffle giảm từ 742 KB xuống 106 KB. Chạy lại job khi tắt Combiner cho ra kết quả giống hệt, nghĩa là Combiner không làm sai kết quả.

**▶ Làm:** Ctrl + click link JobHistory trong khung XONG → bấm job → Counters.

> Trên JobHistory cũng thấy đúng các bộ đếm này. Nhóm em có thêm 5 test case, từ TC1 đến TC5, kiểm tra lần lượt làm sạch, Combiner, Partitioner, tính toán và đối chiếu với dữ liệu thật; cả 5 đều PASS.
>
> Em mời bạn Quốc trình bày Spark và HBase.

---

## Phần 5. Câu 6, 7 – Vũ Văn Quốc, 4 phút

**▶ Làm:** chạy `bash ~/src/demo/cau06.sh`.

> Em là Quốc, em phụ trách Câu 6 và Câu 7. Câu 6 là pipeline xử lý bằng PySpark, chạy trên YARN.

**▶ Khi hiện kết quả pipeline:**

> Spark đọc dữ liệu raw, làm sạch theo đúng quy tắc chung, cũng ra 14.408 đơn, rồi ghi vùng curated dạng Parquet, chia phân vùng theo năm, tháng và danh mục để truy vấn sau chỉ đọc đúng phần cần. Pipeline có 7 phép biến đổi và 9 hành động; dùng cache cho DataFrame dùng lại nhiều lần giúp chạy nhanh hơn 1,56 lần.

**▶ Khi hiện sản phẩm và khách hàng:**

> Hai kết quả phân tích: **64 sản phẩm tăng trưởng nhanh**, so 3 tháng cuối với 3 tháng liền trước; và **369 khách có nguy cơ rời bỏ**, tính theo mô hình RFM: lần mua gần nhất, tần suất và giá trị.

**▶ Làm:** mở `localhost:18080` → app mới nhất → Jobs, Storage.

> Trên Spark History có thể thấy các job, stage và DataFrame đang được cache.

**▶ Làm:** chạy `bash ~/src/demo/cau07.sh`.

> Câu 7 là thiết kế bảng HBase để chăm sóc khách hàng tra cứu lịch sử đơn của một khách. Rowkey là **mã khách, dấu thăng, rồi thời gian đảo ngược**. Nhờ vậy đơn của cùng một khách nằm liền nhau và đơn mới nhất lên đầu.

**▶ Khi hiện lệnh scan:**

> Chỉ cần một lần quét theo tiền tố mã khách là lấy được 5 đơn mới nhất, không phải sắp xếp. Bảng có 3 column family: thông tin đơn, tiền, và giao hàng. Riêng họ giao hàng giữ 5 phiên bản nên xem được lịch sử trạng thái: đặt hàng, đã giao, rồi bị trả. Bảng được nén SNAPPY, nhỏ hơn 5,79 lần so với không nén.

**▶ Làm:** mở `localhost:16010` → `btl:customer_orders`.

> Bảng được chia sẵn thành 6 region, phân đều cho 3 RegionServer. Em mời bạn Quyết trình bày phần phân tích và trực quan hóa.

---

## Phần 6. Câu 8, 9 – Phạm Văn Quyết, 4 phút

**▶ Làm:** mở `localhost:8787` (RStudio). Ở ô Console dán `setwd("~/src/cau08_bigsheets"); source("dashboard.R")`.

> Em là Quyết, em phụ trách Câu 8 và Câu 9. Câu 8 yêu cầu dashboard theo quy trình BigSheets. Môi trường của nhóm không có IBM BigSheets, nên em làm lại đúng các bước của BigSheets bằng R: tạo collection, lọc, nối bảng, nhóm, rồi vẽ biểu đồ. Hướng dẫn thao tác trên BigSheets thật có trong báo cáo.

**▶ Làm:** Files → `output/hinh` → `cau08-dashboard.png`.

> Dashboard gồm doanh thu, tỷ lệ trả và thời gian giao theo danh mục và theo tỉnh. Books có doanh thu cao nhất; Fashion có tỷ lệ trả cao nhất, 8,5%.

**▶ Làm:** Console: `setwd("~/src/cau09_r"); source("phan_tich.R")`.

> Câu 9 phân tích bằng R trên CSDL SQLite của đề: kết nối SQLite, truy vấn SQL, xử lý bằng dplyr, vẽ bằng ggplot2, rồi ghi kết quả ngược lại vào CSDL.
>
> Mô hình hồi quy doanh thu đạt **R² trên tập kiểm tra là 0,833**: số lượng và giá niêm yết giải thích phần lớn doanh thu.
>
> Mô hình phân loại đơn có bị trả hay không chỉ đạt **AUC 0,49**, ngang với đoán ngẫu nhiên. Em kiểm tra bằng kiểm định χ² thì tỷ lệ trả gần như bằng nhau ở mọi nhóm, p đều lớn hơn 0,12. Tức là dữ liệu hiện có không chứa tín hiệu để dự đoán hoàn trả; nhóm báo cáo trung thực kết quả này và đề xuất thu thập thêm lý do trả hàng.

**▶ Làm:** mở `output/hinh/cau09-roc.png`.

> Em xin mời bạn Hiếu trình bày Câu 10 và tổng kết.

---

## Phần 7. Câu 10 và kết luận – Hiếu, 3 phút

**▶ Làm:** tab `may1`, chạy `bash ~/src/demo/cau10.sh`.

> Câu 10 là đối chiếu ba công cụ. Pig, MapReduce và Spark do ba bạn viết độc lập, cùng tính doanh thu và tỷ lệ trả theo danh mục và tháng. Kết quả: ba tệp có mã md5 giống hệt nhau, **0 ô sai khác trên 114 ô**, và tổng khớp với Câu 1. Đây là bằng chứng quy tắc làm sạch được áp dụng thống nhất.
>
> Về thời gian, MapReduce khoảng 18 đến 20 giây, Spark khoảng 20 giây, Pig khoảng 63 giây. Ở quy mô dữ liệu này, phần lớn thời gian là khởi động job, nên Spark chưa thể hiện ưu thế; với dữ liệu lớn hơn nhiều block thì Spark sẽ nhanh hơn nhờ xử lý trong bộ nhớ.

**▶ Làm:** mở báo cáo tới Bảng khuyến nghị (mục 4.5.4).

> Từ kết quả phân tích, nhóm em đưa ra 7 khuyến nghị. Em xin nêu ba khuyến nghị có căn cứ chắc chắn nhất:
>
> Thứ nhất, về doanh thu: nên **tăng giá trị giỏ bằng combo và khuyến mại theo số lượng** thay vì giảm giá sâu, vì số lượng giải thích 55% biến thiên doanh thu, còn giảm giá chỉ 2,5% và không làm giảm tỷ lệ trả.
>
> Thứ hai, về giao hàng: **cam kết giao trong 5 ngày** và xử lý riêng 7% đơn vượt ngưỡng; dữ liệu cho thấy giao nhanh hơn không làm giảm hoàn trả.
>
> Thứ ba: **nâng chất lượng dữ liệu nguồn**, bổ sung mã khách, mã sản phẩm vào sự kiện và thu thập lý do trả hàng, vì thiếu các trường này nên chưa dự đoán được hoàn trả.

*(có thể bỏ)*

> Hạn chế của đề tài: dữ liệu giả lập khá đồng đều nên nhiều tín hiệu yếu; dữ liệu nhỏ nên phép so hiệu năng chủ yếu đo thời gian khởi động; cụm chưa có dự phòng cho NameNode. Hướng phát triển là thêm Kafka và Spark Streaming cho lớp thời gian thực, và thử ở quy mô 10 đến 100 GB.

> Phần trình bày của nhóm em đến đây là hết. Em cảm ơn cô đã lắng nghe, nhóm em rất mong nhận được nhận xét của cô.

---

## Hỏi đáp – chuẩn bị trước

Ai phụ trách câu nào thì trả lời câu đó; câu chung do Hiếu trả lời.

| Câu hỏi | Ai trả lời | Ý trả lời |
|---|---|---|
| 7 MB thì sao gọi là Big Data? | Hiếu | Đây là mẫu thu nhỏ; ước tính sàn thật khoảng 169 GB/năm, khoảng 507 GB khi nhân bản 3 (Bảng 1.4). Bài toán có đủ đặc trưng: nhiều nguồn, nhiều định dạng, dữ liệu luồng, dữ liệu lỗi. Hệ thống viết để mở rộng được khi dữ liệu lớn lên |
| Vì sao Pig chậm nhất? | Hiệp | Pig dịch thành nhiều job MapReduce (17 job với script đầy đủ; 3 job với phép tính đối chiếu vì có ORDER). Mỗi job tốn 15–20 s khởi động, dữ liệu nhỏ nên phần khởi động chiếm gần hết |
| Combiner có làm sai kết quả không? | Hiệp | Không, vì Combiner chỉ cộng các tổng con (số đơn, doanh thu, số đơn trả), tỷ lệ chỉ tính ở Reducer. TC2 chứng minh bật/tắt cho cùng kết quả |
| Vì sao rowkey có thời gian đảo ngược? | Quốc | HBase sắp xếp rowkey tăng dần; đảo ngược thời gian để đơn mới nhất đứng đầu, một lần scan theo tiền tố là lấy được N đơn mới nhất |
| Rowkey có bị dồn vào một region không? | Quốc | Không, vì bắt đầu bằng mã khách nên rải đều; bảng chia sẵn 6 region theo khoảng mã khách |
| Mất 1 node mà nhân bản 3 thì sao? | Duy | Vẫn đọc được vì còn 2 bản sao. Cụm chỉ có 3 DataNode nên tệp nhân bản 3 không thể đủ lại 3 bản; triển khai thật nên có từ 4 DataNode |
| FileChannel và MemoryChannel khác nhau thế nào? | Duy | FileChannel ghi xuống đĩa, chậm hơn nhưng không mất sự kiện khi agent chết; MemoryChannel nhanh nhưng mất hết. Thí nghiệm kill -9: 1000/1000 so với 0/1000 |
| AUC 0,49 có phải mô hình hỏng? | Quyết | Không. Kiểm định χ² cho thấy tỷ lệ trả đều ở mọi nhóm (p > 0,12), dữ liệu không có tín hiệu. Accuracy 92% chỉ bằng đoán "không trả" cho mọi đơn |
| Vì sao không dùng Kafka? | Hiếu | Đề cho chọn HTTP, Netcat hoặc Kafka; nhóm dùng HTTP. Kafka nằm trong hướng phát triển |
| Vì sao không dùng BigSheets thật? | Quyết | Môi trường không có IBM BigInsights; nhóm làm lại đúng các bước bằng R và viết hướng dẫn thao tác BigSheets trong báo cáo |
| Cụm chạy trên máy nào? | Hiếu | **Trả lời đúng sự thật**, như báo cáo mục 3.1 đã ghi: 4 node chạy trên một máy tính, toàn bộ cấu hình Hadoop do nhóm tự viết và kiểm thử tự động |
