-- 01_data_audit.sql
-- Checks on the raw tables, and the cleaned reviews view used later.

USE e_commerce_store;


-- 1. Row count of each table
SELECT COUNT(*) total_rows, 'customers_tbl' tabel_name
FROM customers
UNION ALL
SELECT COUNT(*) total_rows, 'geolocation1_tbl' tabel_name
FROM geolocation1
UNION ALL
SELECT COUNT(*) total_rows, 'order_payments_tbl' tabel_name
FROM order_payments
UNION ALL
SELECT COUNT(*) total_rows, 'order_reviews_tbl' tabel_name
FROM order_reviews
UNION ALL
SELECT COUNT(*) total_rows, 'orders_tbl' tabel_name
FROM orders
UNION ALL
SELECT COUNT(*) total_rows, 'orders_items_tbl' tabel_name
FROM orders_items
UNION ALL
SELECT COUNT(*) total_rows, 'product_tbl' tabel_name
FROM product
UNION ALL
SELECT COUNT(*) total_rows, 'sellers_tbl' tabel_name
FROM sellers;


-- 2. Date range of the orders
SELECT
    MIN(order_purchase_timestamp) min_ordr_date,
    MAX(order_purchase_timestamp) max_ordr_date
FROM orders;


-- 3. Orders per month
SELECT
    DATE_FORMAT(order_purchase_timestamp, '%Y-%m') months,
    COUNT(*) total_orders
FROM orders
GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
ORDER BY months;


-- 4. Orders by status
SELECT
    order_status,
    COUNT(*) total_orders,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 3) percentage_total
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;


-- 5. Missing timestamps by status
SELECT
    order_status,
    COUNT(CASE WHEN order_approved_at IS NULL THEN order_id END) null_cnt_order_approved,
    COUNT(CASE WHEN order_delivered_carrier_date IS NULL THEN order_id END) null_cnt_order_delivered_carrier,
    COUNT(CASE WHEN order_delivered_customer_date IS NULL THEN order_id END) null_cnt_order_delivered_customer,
    COUNT(CASE WHEN order_estimated_delivery_date IS NULL THEN order_id END) null_cnt_order_estimated_delivery
FROM orders
GROUP BY order_status;


-- 6. Duplicate order ids in orders
SELECT
    order_id,
    COUNT(*) rep
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;


-- 7. Orders with more than one review
SELECT
    order_id,
    COUNT(*) rep
FROM order_reviews
GROUP BY order_id
HAVING COUNT(*) > 1;


-- 8. Orders with more than one review, against all reviewed orders
WITH order_rev_stats AS (
    SELECT
        order_id,
        COUNT(*) rep
    FROM order_reviews
    GROUP BY order_id
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) total_dup_orders,
    (SELECT COUNT(DISTINCT order_id) FROM order_reviews) total_unq_orders
FROM order_rev_stats;


-- 9. Do repeated reviews on one order give different scores?
WITH rev_score_com AS (
    SELECT
        order_id,
        MIN(review_score) min_score,
        MAX(review_score) max_score,
        ABS(MIN(review_score) - MAX(review_score)) score_diff
    FROM order_reviews
    GROUP BY order_id
    HAVING COUNT(*) > 1
),
order_rev_summ AS (
    SELECT
        *,
        CASE
            WHEN score_diff = 0 THEN 'No-Diff'
            ELSE 'Diff'
        END diff_type
    FROM rev_score_com
)
SELECT
    diff_type,
    COUNT(*) total_orders
FROM order_rev_summ
GROUP BY diff_type;


-- 10. Do repeated reviews on one order have different dates?
WITH rev_date_comp AS (
    SELECT
        order_id,
        MIN(review_answer_timestamp) first_rev_date,
        MAX(review_answer_timestamp) last_rev_date,
        DATEDIFF(MAX(review_answer_timestamp), MIN(review_answer_timestamp)) date_diff
    FROM order_reviews
    GROUP BY order_id
    HAVING COUNT(*) > 1
),
order_revdate_summ AS (
    SELECT
        *,
        CASE
            WHEN date_diff = 0 THEN 'No-Diff'
            ELSE 'Diff'
        END Diff_type
    FROM rev_date_comp
)
SELECT
    Diff_type,
    COUNT(*) total_orders
FROM order_revdate_summ
GROUP BY Diff_type;


-- 11. Cleaned reviews view: the latest review for each order
CREATE VIEW v_reviews_clean AS
WITH cleaned_tbl AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY review_answer_timestamp DESC, review_id DESC) rev_rnk
    FROM order_reviews
)
SELECT *
FROM cleaned_tbl
WHERE rev_rnk = 1;


-- 12. Checks on the view: row count, and any order appearing twice
SELECT COUNT(*)
FROM v_reviews_clean;

SELECT order_id
FROM v_reviews_clean
GROUP BY order_id
HAVING COUNT(*) > 1;


-- 13. Customers with one order and with repeat orders (delivered orders, no date filter)
WITH cust_ana AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) total_orders
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
    ORDER BY total_orders DESC
),
cust_ana_agg AS (
    SELECT
        customer_unique_id,
        CASE
            WHEN total_orders > 1 THEN "repeat_cust"
            ELSE 'one_time_cust'
        END cust_status
    FROM cust_ana
    GROUP BY customer_unique_id
)
SELECT
    cust_status,
    COUNT(*) total_cust,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 2) pct_cust
FROM cust_ana_agg
GROUP BY cust_status;


-- 14. Orders with no items, by status
SELECT
    o.order_status,
    COUNT(*) total_null
FROM orders o
LEFT JOIN orders_items ot
    ON o.order_id = ot.order_id
WHERE ot.order_id IS NULL
GROUP BY o.order_status;


-- 15. Orders with no payment record, by status
SELECT
    o.order_status,
    COUNT(*) total_null
FROM orders o
LEFT JOIN order_payments op
    ON o.order_id = op.order_id
WHERE op.order_id IS NULL
GROUP BY o.order_status;


-- 16. Timestamps that are out of order
SELECT
    SUM(CASE WHEN order_approved_at < order_purchase_timestamp THEN 1 ELSE 0 END) approval_befr_pur,
    SUM(CASE WHEN order_delivered_carrier_date < order_approved_at THEN 1 ELSE 0 END) pickup_befr_appr,
    SUM(CASE WHEN order_delivered_customer_date < order_delivered_carrier_date THEN 1 ELSE 0 END) delivered_before_pickup,
    SUM(CASE WHEN order_purchase_timestamp > order_delivered_customer_date THEN 1 ELSE 0 END) delivered_before_purchase
FROM orders
WHERE order_purchase_timestamp IS NOT NULL;
