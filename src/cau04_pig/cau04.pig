/*
 * Cau 4 - Pig Latin: lam sach don hang (vung staging) va phan tich theo danh muc x phan khuc.
 *   pig -x mapreduce -f cau04_pig/cau04.pig                    (cum, ban chup 2026-08-01)
 *   pig -x local -param RAW=... -param STAGING=... -param OUT=... -f cau04.pig   (test.sh)
 * "Bang su kien" = bang su kien don hang orders (fact_main, moi dong la 1 su kien dat hang),
 * JOIN voi 2 bang danh muc customers va products. Su kien JSON (events_stream.jsonl) khong co
 * customer_id/product_id nen chi JOIN voi orders theo ma don de kiem tra nhat quan.
 * Quy tac lam sach: docs/quy-uoc.md muc 2.
 */
%default SNAP '2026-08-01'
%default RAW '/btl/raw'
%default STAGING '/btl/staging/orders'
%default OUT '/btl/output/cau04_pig'
-- PAR = so reducer mac dinh: du lieu nho (15.000 dong) nen 1 reducer moi job la du
%default PAR '1'

SET job.name 'cau04_pig';
SET default_parallel $PAR;

-- Chay lai nhieu lan: xoa ket qua cu (STORE khong ghi de thu muc da co)
rmf $STAGING
rmf $OUT

-- ======================================================================
-- 1. LOAD + khai bao schema
-- ======================================================================
orders_raw = LOAD '$RAW/orders/ingest_date=$SNAP/orders.csv' USING PigStorage(',') AS (
    record_id:chararray, order_ts:chararray, province:chararray, source_system:chararray,
    ingest_mode:chararray, data_format:chararray, order_id:chararray, customer_id:chararray,
    product_id:chararray, category:chararray, customer_segment:chararray,
    sales_channel:chararray, quantity:int, unit_price:double, discount_rate:double,
    shipping_fee:double, net_revenue:double, payment_method:chararray,
    delivery_days:double, returned_flag:int, review_score:int, campaign_id:chararray,
    quality_flag:chararray);

customers_raw = LOAD '$RAW/customers/ingest_date=$SNAP/customers.csv' USING PigStorage(',') AS (
    customer_id:chararray, customer_segment:chararray, age_group:chararray,
    gender:chararray, home_province:chararray, join_date:chararray, loyalty_score:int,
    preferred_channel:chararray);

products_raw = LOAD '$RAW/products/ingest_date=$SNAP/products.csv' USING PigStorage(',') AS (
    product_id:chararray, category:chararray, brand:chararray, unit_cost:double,
    list_price:double, supplier_id:chararray, rating:double, active_flag:int);

-- Du lieu ban cau truc: JSON Lines co truong long payload (tuple)
events = LOAD '$RAW/events/ingest_date=$SNAP/events_stream.jsonl' USING JsonLoader(
    'event_id:chararray, event_time:chararray, event_type:chararray, source:chararray, payload:(category:chararray, customer_segment:chararray, net_revenue:double, returned_flag:int)');

DESCRIBE orders_raw;
DESCRIBE events;

-- ======================================================================
-- 2. FILTER ban ghi khong hop le
--    Dong tieu de (bat dau bang BOM nen dung MATCHES '.*record_id'), thieu khoa, sai kieu so
--    (PigStorage tra NULL khi ep kieu loi hoac thieu cot), quality_flag la.
-- ======================================================================
orders_chk = FOREACH orders_raw GENERATE *,
    (record_id MATCHES '.*record_id' ? 'HEADER' :
     ((order_id IS NULL OR order_id == '' OR customer_id IS NULL OR product_id IS NULL
       OR category IS NULL OR category == '' OR province IS NULL OR province == ''
       OR order_ts IS NULL OR SIZE(order_ts) < 19 OR net_revenue IS NULL
       OR returned_flag IS NULL OR (returned_flag != 0 AND returned_flag != 1)
       OR quality_flag IS NULL
       OR NOT (quality_flag == 'OK' OR quality_flag == 'MISSING' OR quality_flag == 'OUTLIER'
               OR quality_flag == 'DUPLICATE' OR quality_flag == 'LATE'))
      ? 'INVALID' : quality_flag)) AS status;

valid = FILTER orders_chk BY status != 'HEADER' AND status != 'INVALID';

-- ======================================================================
-- 3. SPLIT theo quality_flag: giu OK + MISSING, tach OUTLIER/DUPLICATE/LATE ra rieng
-- ======================================================================
SPLIT valid INTO clean IF quality_flag IN ('OK', 'MISSING'), rejected OTHERWISE;

-- ======================================================================
-- 4. FOREACH chuan hoa -> STORE vung staging (tab, khong tieu de, khong BOM)
--    review_score rong giu NULL (khong thay 0); campaign_id rong -> 'NONE';
--    delivery_days -> int (sau khi da bo OUTLIER); them order_month de gom nhom.
-- ======================================================================
staging = FOREACH clean GENERATE
    record_id, order_ts, province, source_system, ingest_mode, data_format, order_id,
    customer_id, product_id, category, customer_segment, sales_channel, quantity,
    unit_price, discount_rate, shipping_fee, net_revenue, payment_method,
    (int) delivery_days AS delivery_days, returned_flag, review_score,
    ((campaign_id IS NULL OR campaign_id == '') ? 'NONE' : campaign_id) AS campaign_id,
    quality_flag,
    SUBSTRING(order_ts, 0, 7) AS order_month;

STORE staging INTO '$STAGING' USING PigStorage('\t', '-schema');
STORE rejected INTO '$OUT/rejected_orders' USING PigStorage('\t', '-schema');

-- Doanh thu tinh bang xu (long) de SUM chinh xac, khong phu thuoc thu tu cong
orders_c = FOREACH staging GENERATE order_id, order_ts, order_month, province, customer_id,
    product_id, category, customer_segment, net_revenue,
    ROUND(net_revenue * 100.0) AS revenue_cents, returned_flag, delivery_days, review_score;

-- ======================================================================
-- 5. JOIN bang su kien don hang voi 2 bang danh muc (replicated: danh muc nho, nap vao bo nho
--    cua moi map task -> map-side join, khong can shuffle)
-- ======================================================================
customers = FILTER customers_raw BY NOT (customer_id MATCHES '.*customer_id');
products  = FILTER products_raw  BY NOT (product_id MATCHES '.*product_id');

j_cust = JOIN orders_c BY customer_id, customers BY customer_id USING 'replicated';
j_prod = JOIN j_cust BY orders_c::product_id, products BY product_id USING 'replicated';

enriched = FOREACH j_prod GENERATE
    orders_c::order_id AS order_id, orders_c::order_month AS order_month,
    orders_c::province AS province, orders_c::customer_id AS customer_id,
    orders_c::product_id AS product_id, orders_c::category AS category,
    orders_c::customer_segment AS customer_segment, orders_c::net_revenue AS net_revenue,
    orders_c::revenue_cents AS revenue_cents, orders_c::returned_flag AS returned_flag,
    orders_c::delivery_days AS delivery_days, orders_c::review_score AS review_score,
    customers::age_group AS age_group, customers::loyalty_score AS loyalty_score,
    products::brand AS brand, products::rating AS rating,
    ((orders_c::category == products::category
      AND orders_c::customer_segment == customers::customer_segment) ? 0 : 1) AS catalog_mismatch;

DESCRIBE enriched;

-- ======================================================================
-- 6. GROUP theo category x customer_segment; FOREACH long nhau voi DISTINCT, FILTER
--    Ham danh gia: COUNT, SUM, AVG, MIN, MAX, SIZE, CONCAT (+ ROUND_TO, SPRINTF, SUBSTRING)
-- ======================================================================
g_seg = GROUP enriched BY (category, customer_segment);
seg_stats = FOREACH g_seg {
    custs = DISTINCT enriched.customer_id;
    rets  = FILTER enriched BY returned_flag == 1;
    GENERATE
        group.category AS category,
        group.customer_segment AS customer_segment,
        CONCAT(group.category, '|', group.customer_segment) AS segment_key,
        COUNT(enriched) AS orders,
        SIZE(custs) AS customers,
        SUM(enriched.revenue_cents) AS revenue_cents,
        COUNT(rets) AS returned,
        ROUND_TO(AVG(enriched.net_revenue), 2) AS avg_order_value,
        MIN(enriched.net_revenue) AS min_order_value,
        MAX(enriched.net_revenue) AS max_order_value,
        ROUND_TO(AVG(enriched.delivery_days), 2) AS avg_delivery_days,
        ROUND_TO(AVG(enriched.review_score), 2) AS avg_review_score;   -- AVG bo qua NULL
};
seg_fmt = FOREACH seg_stats GENERATE category, customer_segment, segment_key, orders, customers,
    SPRINTF('%d.%02d', revenue_cents / 100L, revenue_cents % 100L) AS net_revenue,
    revenue_cents, returned, ROUND_TO(100.0 * returned / orders, 2) AS return_rate_pct,
    avg_order_value, min_order_value, max_order_value, avg_delivery_days, avg_review_score;
-- Ket qua nho (24 dong): ORDER long trong 1 reducer (GROUP ALL), khong ton 2 job lay mau + sap xep
seg_all = GROUP seg_fmt ALL;
seg_sorted = FOREACH seg_all {
    s = ORDER seg_fmt BY revenue_cents DESC;
    GENERATE FLATTEN(s) AS (category, customer_segment, segment_key, orders, customers,
        net_revenue, revenue_cents, returned, return_rate_pct, avg_order_value,
        min_order_value, max_order_value, avg_delivery_days, avg_review_score);
};
STORE seg_sorted INTO '$OUT/segment_stats' USING PigStorage('\t', '-schema');

-- Tong hop theo danh muc (DISTINCT long nhau: so khach hang khac nhau)
g_cat = GROUP enriched BY category;
cat_stats = FOREACH g_cat {
    custs = DISTINCT enriched.customer_id;
    GENERATE group AS category, COUNT(enriched) AS orders, SIZE(custs) AS customers,
        SUM(enriched.revenue_cents) AS revenue_cents, SUM(enriched.returned_flag) AS returned,
        ROUND_TO(AVG(enriched.delivery_days), 2) AS avg_delivery_days;
};
cat_all = GROUP cat_stats ALL;
cat_sorted = FOREACH cat_all {
    s = ORDER cat_stats BY orders DESC;
    GENERATE FLATTEN(s) AS (category, orders, customers, revenue_cents, returned, avg_delivery_days);
};
cat_fmt = FOREACH cat_sorted GENERATE category, orders, customers,
    SPRINTF('%d.%02d', revenue_cents / 100L, revenue_cents % 100L) AS net_revenue, returned,
    ROUND_TO(100.0 * returned / orders, 2) AS return_rate_pct, avg_delivery_days;
STORE cat_fmt INTO '$OUT/category_summary' USING PigStorage('\t', '-schema');

-- ======================================================================
-- 7. ORDER + LIMIT (muc quan he): 10 san pham doanh thu cao nhat, kem brand tu bang products
-- ======================================================================
g_prod = GROUP enriched BY (product_id, brand, category);
prod_rev = FOREACH g_prod GENERATE FLATTEN(group) AS (product_id, brand, category),
    COUNT(enriched) AS orders, SUM(enriched.revenue_cents) AS revenue_cents,
    SUM(enriched.returned_flag) AS returned, MAX(enriched.rating) AS rating;
prod_sorted = ORDER prod_rev BY revenue_cents DESC, product_id ASC;
top10 = LIMIT prod_sorted 10;
top10_fmt = FOREACH top10 GENERATE product_id, brand, category, orders,
    SPRINTF('%d.%02d', revenue_cents / 100L, revenue_cents % 100L) AS net_revenue, returned, rating;
STORE top10_fmt INTO '$OUT/top10_products' USING PigStorage('\t', '-schema');

-- ======================================================================
-- 8. Tep doi chieu Pig - MapReduce - Spark (docs/quy-uoc.md muc 3)
--    Ty le tra x100 lam tron HALF_UP bang so nguyen: (20000*returned + orders) / (2*orders)
-- ======================================================================
g_cm = GROUP orders_c BY (category, order_month);
cm = FOREACH g_cm GENERATE group.category AS category, group.order_month AS month,
    COUNT(orders_c) AS orders, SUM(orders_c.revenue_cents) AS cents,
    SUM(orders_c.returned_flag) AS returned;
cm_rate = FOREACH cm GENERATE category, month, orders, cents, returned,
    (20000L * returned + orders) / (2L * orders) AS rate_x100;
cm_fmt = FOREACH cm_rate GENERATE category, month, orders,
    SPRINTF('%d.%02d', cents / 100L, cents % 100L) AS net_revenue, returned,
    SPRINTF('%d.%02d', rate_x100 / 100L, rate_x100 % 100L) AS return_rate_pct;
cm_all = GROUP cm_fmt ALL;
cm_sorted = FOREACH cm_all {
    s = ORDER cm_fmt BY category ASC, month ASC;
    GENERATE FLATTEN(s) AS (category, month, orders, net_revenue, returned, return_rate_pct);
};
STORE cm_sorted INTO '$OUT/compare_category_month' USING PigStorage(',', '-schema');

-- ======================================================================
-- 9. Su kien JSON: bo tien to 'EVT-' -> ma don, JOIN voi don hop le (ca don bi loai)
--    de kiem tra nhat quan; KHONG cong su kien vao doanh thu (trung voi don goc).
-- ======================================================================
ev = FOREACH events GENERATE event_id, REPLACE(event_id, '^EVT-', '') AS order_id, event_time,
    source, payload.category AS category, payload.customer_segment AS customer_segment,
    payload.net_revenue AS net_revenue, payload.returned_flag AS returned_flag;
ev_j = JOIN ev BY order_id LEFT OUTER, valid BY order_id;
ev_chk = FOREACH ev_j GENERATE
    (valid::order_id IS NULL ? 'NO_ORDER' : valid::quality_flag) AS order_quality_flag,
    ((valid::order_id IS NOT NULL AND ev::event_time == valid::order_ts
      AND ev::source == valid::source_system AND ev::category == valid::category
      AND ev::customer_segment == valid::customer_segment
      AND ev::net_revenue == valid::net_revenue
      AND ev::returned_flag == valid::returned_flag) ? 1 : 0) AS fields_match;
g_ev = GROUP ev_chk BY order_quality_flag;
ev_summary = FOREACH g_ev GENERATE group AS order_quality_flag, COUNT(ev_chk) AS events,
    SUM(ev_chk.fields_match) AS events_matching_order;
STORE ev_summary INTO '$OUT/event_check' USING PigStorage('\t', '-schema');

-- ======================================================================
-- 10. So lieu kiem tra tung buoc (UNION cac chi so; run.sh/test.sh sap xep lai)
--     - raw_status_*      : FILTER (HEADER, INVALID) va nhan quality_flag
--     - distinct_content  : DISTINCT tren 20 cot noi dung (bo record_id, order_id,
--                           quality_flag) -> neu = so dong hop le thi DUPLICATE khong phai
--                           trung noi dung, DISTINCT khong thay the duoc loc theo nhan
--     - join_*            : so don sau JOIN va so don lech danh muc
-- ======================================================================
g_status = GROUP orders_chk BY status;
m_status = FOREACH g_status GENERATE CONCAT('raw_status_', group) AS metric,
    COUNT(orders_chk) AS value;

content = FOREACH valid GENERATE order_ts, province, source_system, ingest_mode, data_format,
    customer_id, product_id, category, customer_segment, sales_channel, quantity, unit_price,
    discount_rate, shipping_fee, net_revenue, payment_method, delivery_days, returned_flag,
    review_score, campaign_id;
content_u = DISTINCT content;
g_content = GROUP content_u ALL;
m_content = FOREACH g_content GENERATE 'distinct_content_rows' AS metric, COUNT(content_u) AS value;

g_enr = GROUP enriched ALL;
m_enr = FOREACH g_enr GENERATE 'join_enriched_orders' AS metric, COUNT(enriched) AS value;
m_mis = FOREACH g_enr GENERATE 'join_catalog_mismatch' AS metric,
    SUM(enriched.catalog_mismatch) AS value;

checks = UNION m_status, m_content, m_enr, m_mis;
STORE checks INTO '$OUT/checks' USING PigStorage('\t', '-schema');
