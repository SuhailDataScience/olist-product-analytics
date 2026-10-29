-- 05_drop_off_drivers.sql
-- Delivery time, reviews and returning customers.
-- Uses the v_reviews_clean view created in 01_data_audit.sql.


-- 1. Review scores by delivery time range (valid orders)
WITH orders_delivery_time AS (
    SELECT
        order_id,
        TIMESTAMPDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date) delivery_time,
        CASE
            WHEN TIMESTAMPDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date) <= 7 THEN 'up to 7 days'
            WHEN TIMESTAMPDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date) >= 8
                AND TIMESTAMPDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date) <= 14 THEN '8-14 days'
            WHEN TIMESTAMPDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date) >= 15
                AND TIMESTAMPDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date) <= 21 THEN '15-21 days'
            WHEN TIMESTAMPDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date) >= 22
                AND TIMESTAMPDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date) <= 30 THEN '22-30 days'
            ELSE 'over 30 days'
        END delivered_type
    FROM orders
    WHERE order_status = 'delivered'
        AND (order_purchase_timestamp >= '2017-01-01'
            AND order_purchase_timestamp < '2018-09-01')
        AND order_purchase_timestamp IS NOT NULL
        AND order_approved_at IS NOT NULL
        AND order_delivered_carrier_date IS NOT NULL
        AND order_delivered_customer_date IS NOT NULL
        AND order_purchase_timestamp <= order_approved_at
        AND order_approved_at <= order_delivered_carrier_date
        AND order_delivered_carrier_date <= order_delivered_customer_date
)
SELECT
    o.delivered_type AS delivery_range,
    COUNT(o.order_id) total_orders,
    COUNT(r.review_score) orders_with_reviews,
    ROUND(AVG(r.review_score), 2) avg_review_score,
    ROUND(COUNT(CASE
        WHEN r.review_score IN (1, 2) THEN o.order_id
    END) / NULLIF(COUNT(r.review_score), 0) * 100, 2) low_score_pct
FROM orders_delivery_time o
LEFT JOIN v_reviews_clean r
    ON o.order_id = r.order_id
GROUP BY o.delivered_type
ORDER BY FIELD(o.delivered_type, 'up to 7 days', '8-14 days', '15-21 days', '22-30 days', 'over 30 days');


-- 2. Share of customers returning within 90 days, by delivery time of their first order
WITH cust AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        TIMESTAMPDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date) days_diff,
        o.order_purchase_timestamp
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
        AND (o.order_purchase_timestamp >= '2017-01-01'
            AND o.order_purchase_timestamp < '2018-09-01')
        AND o.order_purchase_timestamp IS NOT NULL
        AND o.order_approved_at IS NOT NULL
        AND o.order_delivered_carrier_date IS NOT NULL
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_purchase_timestamp <= o.order_approved_at
        AND o.order_approved_at <= o.order_delivered_carrier_date
        AND o.order_delivered_carrier_date <= o.order_delivered_customer_date
),
cust_first_pur AS (
    SELECT
        customer_unique_id,
        MIN(order_purchase_timestamp) first_purchase_ts
    FROM cust
    GROUP BY customer_unique_id
    HAVING MIN(order_purchase_timestamp) < '2018-06-01'
),
cust_aggregation AS (
    SELECT
        c.customer_unique_id,
        MAX(c.days_diff) days_taken,
        CASE
            WHEN MAX(c.days_diff) <= 7 THEN 'up to 7 days'
            WHEN MAX(c.days_diff) >= 8
                AND MAX(c.days_diff) <= 14 THEN '8-14 days'
            WHEN MAX(c.days_diff) >= 15
                AND MAX(c.days_diff) <= 21 THEN '15-21 days'
            WHEN MAX(c.days_diff) >= 22
                AND MAX(c.days_diff) <= 30 THEN '22-30 days'
            ELSE 'over 30 days'
        END delivered_type
    FROM cust c
    JOIN cust_first_pur f
        ON c.customer_unique_id = f.customer_unique_id
        AND c.order_purchase_timestamp = f.first_purchase_ts
    GROUP BY c.customer_unique_id
),
second_pur AS (
    SELECT
        c.customer_unique_id,
        f.first_purchase_ts,
        MIN(c.order_purchase_timestamp) second_purchase_ts,
        CASE
            WHEN TIMESTAMPDIFF(DAY, f.first_purchase_ts, MIN(c.order_purchase_timestamp)) <= 90 THEN 1
            ELSE 0
        END came_back_in_90days
    FROM cust c
    JOIN cust_first_pur f
        ON c.customer_unique_id = f.customer_unique_id
    WHERE c.order_purchase_timestamp > f.first_purchase_ts
    GROUP BY c.customer_unique_id, f.first_purchase_ts
)
SELECT
    c.delivered_type,
    COUNT(DISTINCT c.customer_unique_id) total_cust,
    SUM(COALESCE(came_back_in_90days, 0)) returned_90_days,
    ROUND(SUM(COALESCE(s.came_back_in_90days, 0)) / COUNT(c.customer_unique_id) * 100, 2) returned_90_days_pct
FROM cust_aggregation c
LEFT JOIN second_pur s
    ON c.customer_unique_id = s.customer_unique_id
GROUP BY c.delivered_type
ORDER BY FIELD(c.delivered_type, 'up to 7 days', '8-14 days', '15-21 days', '22-30 days', 'over 30 days');


-- 3. Share of customers returning within 90 days, by review score of their first order
WITH cust AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        TIMESTAMPDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date) days_diff,
        o.order_purchase_timestamp,
        r.review_score
    FROM orders o
    LEFT JOIN v_reviews_clean r
        ON o.order_id = r.order_id
    LEFT JOIN customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
        AND (o.order_purchase_timestamp >= '2017-01-01'
            AND o.order_purchase_timestamp < '2018-09-01')
        AND o.order_purchase_timestamp IS NOT NULL
        AND o.order_approved_at IS NOT NULL
        AND o.order_delivered_carrier_date IS NOT NULL
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_purchase_timestamp <= o.order_approved_at
        AND o.order_approved_at <= o.order_delivered_carrier_date
        AND o.order_delivered_carrier_date <= o.order_delivered_customer_date
),
cust_first_pur AS (
    SELECT
        customer_unique_id,
        MIN(order_purchase_timestamp) first_purchase_ts
    FROM cust c
    GROUP BY customer_unique_id
    HAVING MIN(order_purchase_timestamp) < '2018-06-01'
),
cust_review_group AS (
    SELECT
        c.customer_unique_id,
        MIN(c.review_score) review_score,
        CASE
            WHEN MIN(c.review_score) IS NULL THEN 'No reviews'
            WHEN MIN(c.review_score) BETWEEN 1 AND 2 THEN '1-2 review stars'
            WHEN MIN(c.review_score) = 3 THEN '3 review stars'
            WHEN MIN(c.review_score) > 3 THEN '4-5 review stars'
        END review_type
    FROM cust c
    JOIN cust_first_pur f
        ON c.customer_unique_id = f.customer_unique_id
        AND c.order_purchase_timestamp = f.first_purchase_ts
    GROUP BY c.customer_unique_id
),
second_pur AS (
    SELECT
        c.customer_unique_id,
        f.first_purchase_ts,
        MIN(c.order_purchase_timestamp) second_purchase_ts,
        CASE
            WHEN TIMESTAMPDIFF(DAY, f.first_purchase_ts, MIN(c.order_purchase_timestamp)) <= 90 THEN 1
            ELSE 0
        END came_back_in_90days
    FROM cust c
    JOIN cust_first_pur f
        ON c.customer_unique_id = f.customer_unique_id
    WHERE c.order_purchase_timestamp > f.first_purchase_ts
    GROUP BY c.customer_unique_id, f.first_purchase_ts
),
final_tbl AS (
    SELECT
        cr.customer_unique_id,
        cr.review_score,
        cr.review_type,
        COALESCE(s.came_back_in_90days, 0) came_back_in_90days
    FROM cust_review_group cr
    LEFT JOIN second_pur s
        ON cr.customer_unique_id = s.customer_unique_id
)
SELECT
    review_type,
    COUNT(DISTINCT customer_unique_id) total_cust,
    SUM(came_back_in_90days) returned_within_90days,
    ROUND(SUM(came_back_in_90days) / COUNT(DISTINCT customer_unique_id) * 100, 2) returned_pct
FROM final_tbl
GROUP BY review_type
ORDER BY FIELD(review_type, '1-2 review stars', '3 review stars', '4-5 review stars', 'No reviews');


-- 4. Average days in each delivery stage, calculated in seconds (valid orders)
WITH valid AS (
    SELECT
        order_purchase_timestamp AS purchased,
        order_approved_at AS approved,
        order_delivered_carrier_date AS carrier,
        order_delivered_customer_date AS delivered
    FROM orders
    WHERE order_status = 'delivered'
        AND order_purchase_timestamp >= '2017-01-01'
        AND order_purchase_timestamp < '2018-09-01'
        AND order_approved_at IS NOT NULL
        AND order_delivered_carrier_date IS NOT NULL
        AND order_delivered_customer_date IS NOT NULL
        AND order_purchase_timestamp <= order_approved_at
        AND order_approved_at <= order_delivered_carrier_date
        AND order_delivered_carrier_date <= order_delivered_customer_date
)
SELECT
    'Approval' AS stage,
    1 AS stage_order,
    ROUND(AVG(TIMESTAMPDIFF(SECOND, purchased, approved)) / 86400, 2) AS avg_days
FROM valid
UNION ALL
SELECT
    'Pickup',
    2,
    ROUND(AVG(TIMESTAMPDIFF(SECOND, approved, carrier)) / 86400, 2)
FROM valid
UNION ALL
SELECT
    'Carrier to customer',
    3,
    ROUND(AVG(TIMESTAMPDIFF(SECOND, carrier, delivered)) / 86400, 2)
FROM valid
UNION ALL
SELECT
    'Total (check only)',
    4,
    ROUND(AVG(TIMESTAMPDIFF(SECOND, purchased, delivered)) / 86400, 2)
FROM valid;
