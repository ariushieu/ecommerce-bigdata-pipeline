-- Cau 10 - Ban Pig toi gian cua phep tinh doi chieu: doanh thu va ty le tra theo category x thang.
-- Cung logic voi Cau 5 (MapReduce) va category_month_only.py (Spark) de do thoi gian cong bang.
--   pig -x mapreduce -param IN=<orders.csv> -param OUT=<thu muc HDFS> -f category_month.pig
o_raw = LOAD '$IN' USING PigStorage(',') AS (
    record_id:chararray, ts:chararray, province:chararray, source_system:chararray,
    ingest_mode:chararray, data_format:chararray, order_id:chararray, customer_id:chararray,
    product_id:chararray, category:chararray, customer_segment:chararray, sales_channel:chararray,
    quantity:int, unit_price:double, discount_rate:double, shipping_fee:double,
    net_revenue:double, payment_method:chararray, delivery_days:double, returned_flag:int,
    review_score:chararray, campaign_id:chararray, quality_flag:chararray);

-- bo dong tieu de (co BOM) va ban ghi OUTLIER/DUPLICATE/LATE, giu MISSING
o_clean = FILTER o_raw BY quality_flag != 'quality_flag'
                     AND quality_flag != 'OUTLIER' AND quality_flag != 'DUPLICATE' AND quality_flag != 'LATE';

-- doanh thu tinh bang xu (so nguyen) de tong khong sai so lam tron
o_rows = FOREACH o_clean GENERATE category, SUBSTRING(ts, 0, 7) AS month,
    (long) ROUND(net_revenue * 100.0) AS cents, returned_flag;

o_grp = GROUP o_rows BY (category, month);
o_agg = FOREACH o_grp GENERATE group.category AS category, group.month AS month,
    COUNT(o_rows) AS orders, SUM(o_rows.cents) AS cents, SUM(o_rows.returned_flag) AS returned;
o_out = FOREACH o_agg GENERATE category, month, orders,
    SPRINTF('%.2f', (double) cents / 100.0) AS net_revenue, returned,
    SPRINTF('%.2f', ROUND_TO(100.0 * returned / orders, 2)) AS return_rate_pct;
o_sorted = ORDER o_out BY category, month PARALLEL 1;
STORE o_sorted INTO '$OUT' USING PigStorage(',');
