-- 02_funnel.sql
-- Order funnel, delivery stages and delivery trends.
-- Window: orders placed 2017-01-01 to 2018-08-31.
-- Valid orders: delivered, all four timestamps present and in order.


-- 1. Orders reaching each stage (all statuses)
SELECT
    COUNT(*) puschased,
    COUNT(order_approved_at) approved,
    COUNT(order_delivered_carrier_date) picked,
    COUNT(order_delivered_customer_date) delivered
FROM orders
WHERE order_purchase_timestamp >= '2017-01-01'
    AND order_purchase_timestamp < '2018-09-01';


-- 2. Same counts by order status
SELECT
    order_status,
    COUNT(*) puschased,
    COUNT(order_approved_at) approved,
    COUNT(order_delivered_carrier_date) picked,
    COUNT(order_delivered_customer_date) delivered
FROM orders
WHERE order_purchase_timestamp >= '2017-01-01'
    AND order_purchase_timestamp < '2018-09-01'
GROUP BY order_status;


-- 3. Share of orders not delivered, by purchase month
WITH delivery_ana AS (
    SELECT
        DATE_FORMAT(order_purchase_timestamp, '%Y-%m') months,
        COUNT(*) total_orders,
        COUNT(CASE WHEN order_status != 'delivered' THEN order_id END) not_delivered
    FROM orders
    WHERE order_purchase_timestamp >= '2017-01-01'
        AND order_purchase_timestamp < '2018-09-01'
    GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
)
SELECT
    months,
    total_orders,
    not_delivered,
    ROUND(not_delivered / total_orders * 100, 2) not_delivered_pct
FROM delivery_ana
ORDER BY months;


-- 4. Non-delivered orders by month and status
WITH monthly AS (
    SELECT
        DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS months,
        order_status,
        COUNT(*) AS status_orders,
        SUM(COUNT(*)) OVER (
            PARTITION BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
        ) AS month_total
    FROM orders
    WHERE order_purchase_timestamp >= '2017-01-01'
        AND order_purchase_timestamp < '2018-09-01'
    GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m'), order_status
)
SELECT
    months,
    order_status,
    status_orders,
    month_total,
    ROUND(status_orders / month_total * 100, 2) AS pct_of_month
FROM monthly
WHERE order_status != 'delivered'
ORDER BY months, status_orders DESC;


-- 5. Purchase to approval, in hours (valid orders)
SELECT
    AVG(TIMESTAMPDIFF(HOUR, order_purchase_timestamp, order_approved_at)) avg_hrs_pur_to_appr,
    MAX(TIMESTAMPDIFF(HOUR, order_purchase_timestamp, order_approved_at)) max_hrs_pur_to_appr,
    MIN(TIMESTAMPDIFF(HOUR, order_purchase_timestamp, order_approved_at)) min_hrs_pur_to_appr
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
    AND order_delivered_carrier_date <= order_delivered_customer_date;


-- 6. Approval to carrier pickup, in days (valid orders)
SELECT
    ROUND(AVG(TIMESTAMPDIFF(DAY, order_approved_at, order_delivered_carrier_date)), 1) avg_days_appr_to_pickup,
    MAX(TIMESTAMPDIFF(DAY, order_approved_at, order_delivered_carrier_date)) max_days_appr_to_pickup,
    MIN(TIMESTAMPDIFF(DAY, order_approved_at, order_delivered_carrier_date)) min_days_appr_to_pickup
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
    AND order_delivered_carrier_date <= order_delivered_customer_date;


-- 7. Carrier pickup to delivery, in days (valid orders)
SELECT
    ROUND(AVG(TIMESTAMPDIFF(DAY, order_delivered_carrier_date, order_delivered_customer_date)), 1) avg_days_pickup_to_delivery,
    MAX(TIMESTAMPDIFF(DAY, order_delivered_carrier_date, order_delivered_customer_date)) max_days_pickup_to_delivery,
    MIN(TIMESTAMPDIFF(DAY, order_delivered_carrier_date, order_delivered_customer_date)) min_days_pickup_to_delivery
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
    AND order_delivered_carrier_date <= order_delivered_customer_date;


-- 8. Purchase to delivery, in days (valid orders)
SELECT
    ROUND(AVG(TIMESTAMPDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date)), 1) avg_days_purchase_to_delivery,
    MAX(TIMESTAMPDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date)) max_days_purchase_to_delivery,
    MIN(TIMESTAMPDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date)) min_days_purchase_to_delivery
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
    AND order_delivered_carrier_date <= order_delivered_customer_date;


-- 9. Number of valid orders
SELECT COUNT(*)
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
    AND order_delivered_carrier_date <= order_delivered_customer_date;


-- 10. Delivery time distribution (valid orders)
WITH delivery_funnel_ana AS (
    SELECT
        order_id,
        DATEDIFF(order_delivered_customer_date, order_purchase_timestamp) total_delivery_days,
        CASE
            WHEN DATEDIFF(order_delivered_customer_date, order_purchase_timestamp) <= 7 THEN 'up to 7 days'
            WHEN DATEDIFF(order_delivered_customer_date, order_purchase_timestamp) >= 8
                AND DATEDIFF(order_delivered_customer_date, order_purchase_timestamp) <= 14 THEN '8-14 days'
            WHEN DATEDIFF(order_delivered_customer_date, order_purchase_timestamp) >= 15
                AND DATEDIFF(order_delivered_customer_date, order_purchase_timestamp) <= 21 THEN '15-21 days'
            WHEN DATEDIFF(order_delivered_customer_date, order_purchase_timestamp) >= 22
                AND DATEDIFF(order_delivered_customer_date, order_purchase_timestamp) <= 30 THEN '22-30 days'
            ELSE 'over 30 days'
        END day_segment
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
    day_segment,
    COUNT(*) total_orders,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 2) pct
FROM delivery_funnel_ana
GROUP BY day_segment
ORDER BY FIELD(day_segment, 'up to 7 days', '8-14 days', '15-21 days', '22-30 days', 'over 30 days');


-- 11. Average delivery time and orders over 21 days, by month (valid orders)
SELECT
    DATE_FORMAT(order_purchase_timestamp, '%Y-%m') months,
    COUNT(*) total_orders,
    ROUND(AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)), 2) avg_delivery_days,
    COUNT(CASE
        WHEN DATEDIFF(order_delivered_customer_date, order_purchase_timestamp) > 21
        THEN order_id
    END) slow_orders,
    ROUND(COUNT(CASE
        WHEN DATEDIFF(order_delivered_customer_date, order_purchase_timestamp) > 21
        THEN order_id
    END) / COUNT(*) * 100, 2) slow_orders_pct
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
GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
ORDER BY months;
