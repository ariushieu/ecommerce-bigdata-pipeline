### Mã nguồn Câu 1, 10 – Nguyễn Quốc Hiếu

**A.1. Kiểm tra độ tin cậy của dữ liệu (Câu 1, `src/cau01_5v/profile_data.py`).** Đoạn mã thử lại công thức doanh thu cho từng đơn và đếm số đơn sai theo nhãn `quality_flag`. Kết quả này cho thấy chỉ nhãn OUTLIER có dấu hiệu nhận biết được trên giá trị (mục 2.3).

```python
# net_revenue = quantity * unit_price * (1 - discount_rate) + shipping_fee
formula_fail = collections.Counter()
for r in orders:
    q, p, d, s, rev = (to_float(r[c]) for c in
                       ("quantity", "unit_price", "discount_rate", "shipping_fee", "net_revenue"))
    if abs(q * p * (1 - d) + s - rev) > 0.05:
        formula_fail[r["quality_flag"]] += 1
```

**A.2. Đối chiếu kết quả ba công cụ (Câu 10, `src/cau10_doi_chieu/compare.py`).** So từng ô (danh mục, tháng) của Pig, MapReduce và Spark với nhau, rồi so tổng với số liệu profiling của Câu 1. Script thoát với mã lỗi nếu có bất kỳ sai khác nào, nên CI phát hiện được ngay.

```python
for name, (rows, _) in data.items():
    if set(rows) != set(ref):
        problems.append(f"{name}: tap o (category, thang) khac {ref_name}")
        continue
    for key, r in rows.items():
        for c in COLS:                      # orders, net_revenue, returned, return_rate_pct
            if r[c] != ref[key][c]:
                problems.append(f"{name} {key} {c}: {r[c]} != {ref[key][c]}")
...
sys.exit(1 if problems else 0)
```

**A.3. Phép tính danh mục × tháng bản Pig tối giản (Câu 10, `src/cau10_doi_chieu/category_month.pig`).** Đây là bản Pig dùng để đo hiệu năng ở mục 4.5.2.

```pig
o_clean = FILTER o_raw BY quality_flag != 'quality_flag'
    AND quality_flag != 'OUTLIER' AND quality_flag != 'DUPLICATE' AND quality_flag != 'LATE';
o_rows  = FOREACH o_clean GENERATE category, SUBSTRING(ts, 0, 7) AS month,
          (long) ROUND(net_revenue * 100.0) AS cents, returned_flag;
o_grp   = GROUP o_rows BY (category, month);
o_agg   = FOREACH o_grp GENERATE group.category AS category, group.month AS month,
          COUNT(o_rows) AS orders, SUM(o_rows.cents) AS cents, SUM(o_rows.returned_flag) AS returned;
o_sorted = ORDER o_agg BY category, month PARALLEL 1;   -- ORDER sinh them 2 job MapReduce
```
