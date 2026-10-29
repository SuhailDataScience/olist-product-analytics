-- 04_revenue.sql
-- Revenue is the sum of item price (freight excluded) on valid orders.


-- 1. Orders, revenue and average order value by month
SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') months,
    COUNT(DISTINCT o.order_id) total_orders,
    SUM(ot.price) revenue,
    ROUND(SUM(ot.price) / COUNT(DISTINCT o.order_id), 2) avg_order_value
FROM orders o
LEFT JOIN orders_items ot
    ON o.order_id = ot.order_id
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
GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
ORDER BY months;


-- 2. Revenue from returning and one-time customers
WITH cust_idnt AS (
    SELECT DISTINCT
        o.order_id,
        c.customer_unique_id,
        o.order_purchase_timestamp
    FROM orders o
    JOIN customers c
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
cust_segmentation AS (
    SELECT
        customer_unique_id,
        COUNT(DISTINCT order_purchase_timestamp) purchase_rep,
        CASE
            WHEN COUNT(DISTINCT order_purchase_timestamp) > 1 THEN 'Returned'
            ELSE 'One-time'
        END cust_segment
    FROM cust_idnt
    GROUP BY customer_unique_id
),
revenue AS (
    SELECT
        order_id,
        SUM(price) revenue
    FROM orders_items
    GROUP BY order_id
),
total_aggregations AS (
    SELECT
        cs.cust_segment,
        COUNT(DISTINCT c.customer_unique_id) total_cust,
        COUNT(DISTINCT c.order_id) total_orders,
        ROUND(SUM(r.revenue), 2) total_revenue,
        ROUND(SUM(r.revenue) / SUM(SUM(r.revenue)) OVER () * 100, 2) revenue_pct,
        ROUND(SUM(r.revenue) / COUNT(DISTINCT c.customer_unique_id), 2) revenue_per_cust,
        ROUND(SUM(r.revenue) / COUNT(DISTINCT c.order_id), 2) avg_order_value
    FROM cust_idnt c
    JOIN cust_segmentation cs
        ON c.customer_unique_id = cs.customer_unique_id
    JOIN revenue r
        ON c.order_id = r.order_id
    GROUP BY cs.cust_segment
)
SELECT *
FROM total_aggregations;


-- 3. Revenue by product category
WITH filters AS (
    SELECT order_id
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
),
filtered_orders AS (
    SELECT
        o.order_id,
        o.product_id,
        o.price
    FROM filters f
    JOIN orders_items o
        ON f.order_id = o.order_id
)
SELECT
    COALESCE(p.product_category_name, 'Unknown') category,
    COUNT(DISTINCT f.order_id) total_orders,
    COUNT(*) items_sold,
    SUM(f.price) revenue,
    ROUND(SUM(f.price) / SUM(SUM(f.price)) OVER () * 100, 2) total_revenue_pct
FROM filtered_orders f
LEFT JOIN product p
    ON f.product_id = p.product_id
GROUP BY p.product_category_name
ORDER BY revenue DESC;


-- 4. Revenue by customer state
WITH filters AS (
    SELECT
        order_id,
        customer_id
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
),
filtered_orders AS (
    SELECT
        o.order_id,
        o.product_id,
        o.price,
        f.customer_id
    FROM filters f
    JOIN orders_items o
        ON f.order_id = o.order_id
)
SELECT
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id) total_cust,
    COUNT(DISTINCT f.order_id) total_orders,
    SUM(f.price) revenue,
    ROUND(SUM(f.price) / SUM(SUM(f.price)) OVER () * 100, 2) total_revenue_pct,
    ROUND(SUM(f.price) / COUNT(DISTINCT c.customer_unique_id), 2) revenue_per_cust,
    ROUND(SUM(f.price) / COUNT(DISTINCT f.order_id), 2) avg_order_value
FROM filtered_orders f
LEFT JOIN customers c
    ON f.customer_id = c.customer_id
GROUP BY c.customer_state
ORDER BY revenue DESC;
