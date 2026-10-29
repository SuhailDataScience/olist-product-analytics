-- 03_cohort_retention.sql
-- Cohorts, retention, repeat customers and time to a second purchase.
-- Customers are customer_unique_id. A cohort is the month of the first valid order.


-- 1. Cohort sizes
WITH cust_first_yr AS (
    SELECT
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) fist_yr
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
    GROUP BY c.customer_unique_id
)
SELECT
    DATE_FORMAT(fist_yr, '%Y-%m') months,
    COUNT(*) total_cust
FROM cust_first_yr
GROUP BY DATE_FORMAT(fist_yr, '%Y-%m')
ORDER BY months;


-- 2. Retention by cohort and months since first order
WITH cust_first_yr AS (
    SELECT
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) fist_yr
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
    GROUP BY c.customer_unique_id
),
cust_months AS (
    SELECT DISTINCT
        o.order_purchase_timestamp,
        c.customer_unique_id
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
comb_res AS (
    SELECT
        cm.customer_unique_id,
        cy.fist_yr,
        cm.order_purchase_timestamp,
        TIMESTAMPDIFF(MONTH, cy.fist_yr, cm.order_purchase_timestamp) months_diff
    FROM cust_months cm
    JOIN cust_first_yr cy
        ON cm.customer_unique_id = cy.customer_unique_id
),
cohort_counts AS (
    SELECT
        DATE_FORMAT(fist_yr, '%Y-%m') first_month,
        months_diff,
        COUNT(DISTINCT customer_unique_id) total_cust
    FROM comb_res
    GROUP BY DATE_FORMAT(fist_yr, '%Y-%m'), months_diff
)
SELECT
    first_month,
    months_diff,
    total_cust,
    SUM(total_cust) OVER (PARTITION BY first_month ORDER BY months_diff) cohort_size,
    ROUND(total_cust / FIRST_VALUE(total_cust) OVER (PARTITION BY first_month ORDER BY months_diff) * 100, 2) retention_pct
FROM cohort_counts
ORDER BY first_month, months_diff;


-- 3. Customers who came back at a later time, by cohort
WITH cust_first_yr AS (
    SELECT
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) fist_yr
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
    GROUP BY c.customer_unique_id
),
cust_months AS (
    SELECT DISTINCT
        o.order_purchase_timestamp,
        c.customer_unique_id
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
comb_res AS (
    SELECT
        cm.customer_unique_id,
        cy.fist_yr,
        cm.order_purchase_timestamp
    FROM cust_months cm
    JOIN cust_first_yr cy
        ON cm.customer_unique_id = cy.customer_unique_id
        AND cm.order_purchase_timestamp > cy.fist_yr
),
rep_cust AS (
    SELECT
        DATE_FORMAT(fist_yr, '%Y-%m') months,
        COUNT(DISTINCT customer_unique_id) total_rep_cust
    FROM comb_res
    GROUP BY DATE_FORMAT(fist_yr, '%Y-%m')
),
cohort_size AS (
    SELECT
        DATE_FORMAT(fist_yr, '%Y-%m') months,
        COUNT(DISTINCT customer_unique_id) cohort_size
    FROM cust_first_yr
    GROUP BY DATE_FORMAT(fist_yr, '%Y-%m')
)
SELECT
    cs.months,
    COALESCE(rc.total_rep_cust, 0) rep_cust,
    cs.cohort_size,
    ROUND(COALESCE(rc.total_rep_cust, 0) / cs.cohort_size * 100, 2) rep_cust_pct
FROM cohort_size cs
LEFT JOIN rep_cust rc
    ON cs.months = rc.months
ORDER BY cs.months;


-- 4. Repeat customers under two definitions: more than one order, or a later purchase time
WITH cust_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS n_orders,
        COUNT(DISTINCT o.order_purchase_timestamp) AS n_purchase_moments
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
        AND o.order_purchase_timestamp >= '2017-01-01'
        AND o.order_purchase_timestamp < '2018-09-01'
        AND o.order_approved_at IS NOT NULL
        AND o.order_delivered_carrier_date IS NOT NULL
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_purchase_timestamp <= o.order_approved_at
        AND o.order_approved_at <= o.order_delivered_carrier_date
        AND o.order_delivered_carrier_date <= o.order_delivered_customer_date
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*) AS total_customers,
    SUM(n_orders >= 2) AS multi_order_customers,
    SUM(n_purchase_moments >= 2) AS later_purchase_customers,
    ROUND(SUM(n_orders >= 2) / COUNT(*) * 100, 2) AS multi_order_pct,
    ROUND(SUM(n_purchase_moments >= 2) / COUNT(*) * 100, 2) AS later_purchase_pct
FROM cust_orders;


-- 5. Days from first to second purchase
WITH first_order AS (
    SELECT
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) first_yr
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
    GROUP BY c.customer_unique_id
),
cust_orders AS (
    SELECT
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
cust_2nd_order AS (
    SELECT
        fr.first_yr,
        MIN(co.order_purchase_timestamp) second_order,
        fr.customer_unique_id,
        TIMESTAMPDIFF(DAY, fr.first_yr, MIN(co.order_purchase_timestamp)) day_diff
    FROM first_order fr
    JOIN cust_orders co
        ON fr.customer_unique_id = co.customer_unique_id
    WHERE co.order_purchase_timestamp > fr.first_yr
    GROUP BY fr.first_yr, fr.customer_unique_id
),
cust_segment AS (
    SELECT
        *,
        CASE
            WHEN day_diff <= 7 THEN '0-7 days'
            WHEN day_diff >= 8 AND day_diff <= 30 THEN '8-30 days'
            WHEN day_diff >= 31 AND day_diff <= 90 THEN '31-90 days'
            WHEN day_diff >= 91 AND day_diff <= 180 THEN '91-180 days'
            ELSE '180+ days'
        END days_between_2nd_purchase
    FROM cust_2nd_order
)
SELECT
    days_between_2nd_purchase,
    COUNT(*) total_cust,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 2) returning_pct
FROM cust_segment
GROUP BY days_between_2nd_purchase
ORDER BY FIELD(days_between_2nd_purchase, '0-7 days', '8-30 days', '31-90 days', '91-180 days', '180+ days');


-- 6. Share of each cohort returning within 90 days (first orders before 2018-06-01)
WITH first_order AS (
    SELECT
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) first_yr
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
    GROUP BY c.customer_unique_id
),
cust_orders AS (
    SELECT
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
cust_2nd_order AS (
    SELECT
        fr.first_yr,
        MIN(co.order_purchase_timestamp) second_order,
        fr.customer_unique_id,
        TIMESTAMPDIFF(DAY, fr.first_yr, MIN(co.order_purchase_timestamp)) day_diff
    FROM first_order fr
    JOIN cust_orders co
        ON fr.customer_unique_id = co.customer_unique_id
    WHERE co.order_purchase_timestamp > fr.first_yr
    GROUP BY fr.first_yr, fr.customer_unique_id
),
cohort_size AS (
    SELECT
        DATE_FORMAT(first_yr, '%Y-%m') months,
        COUNT(*) cohort_size
    FROM first_order
    WHERE first_yr < '2018-06-01'
    GROUP BY DATE_FORMAT(first_yr, '%Y-%m')
),
rep_90 AS (
    SELECT
        DATE_FORMAT(first_yr, '%Y-%m') months,
        COUNT(DISTINCT customer_unique_id) rep_cust
    FROM cust_2nd_order
    WHERE day_diff <= 90
        AND first_yr < '2018-06-01'
    GROUP BY DATE_FORMAT(first_yr, '%Y-%m')
)
SELECT
    cs.months,
    cs.cohort_size,
    COALESCE(r.rep_cust, 0) rep_cust,
    ROUND(COALESCE(r.rep_cust, 0) / cs.cohort_size * 100, 2) rep_cust_pct
FROM cohort_size cs
LEFT JOIN rep_90 r
    ON cs.months = r.months
ORDER BY cs.months;
