-- ==========================================
-- OLIST E-COMMERCE CORE KPI ANALYSIS
-- ==========================================

-- 1. Total delivered orders
SELECT
    COUNT(DISTINCT order_id) AS total_delivered_orders
FROM orders
WHERE order_status = 'delivered';


-- 2. Total product revenue
SELECT
    ROUND(SUM(oi.price)::numeric, 2) AS total_product_revenue
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';


-- 3. Total freight value
SELECT
    ROUND(SUM(oi.freight_value)::numeric, 2) AS total_freight_value
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';


-- 4. Average order value
WITH order_revenue AS (
    SELECT
        o.order_id,
        SUM(oi.price) AS order_revenue
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.order_id
)
SELECT
    ROUND(AVG(order_revenue)::numeric, 2) AS average_order_value
FROM order_revenue;


-- 5. Total unique customers with delivered orders
SELECT
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered';


-- 6. Average items per delivered order
SELECT
    ROUND(
        COUNT(oi.order_item_id)::numeric
        / COUNT(DISTINCT o.order_id),
        2
    ) AS avg_items_per_order
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';

-- ==========================================
-- 7. MONTHLY SALES PERFORMANCE
-- ==========================================

WITH monthly_sales AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp)::date AS month,
        COUNT(DISTINCT o.order_id) AS total_orders,
        COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
        SUM(oi.price) AS revenue
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY 1
)

SELECT
    month,
    total_orders,
    unique_customers,
    ROUND(revenue::numeric, 2) AS revenue,

    ROUND(
        revenue / NULLIF(total_orders, 0),
        2
    ) AS average_order_value,

    ROUND(
        (
            revenue
            - LAG(revenue) OVER (ORDER BY month)
        )
        / NULLIF(
            LAG(revenue) OVER (ORDER BY month),
            0
        )
        * 100,
        2
    ) AS revenue_mom_growth_pct

FROM monthly_sales
ORDER BY month;

-- ==========================================
-- 8. CLEAN MONTHLY SALES TREND
-- Main continuous period: Jan 2017 - Aug 2018
-- ==========================================

WITH monthly_sales AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp)::date AS month,
        COUNT(DISTINCT o.order_id) AS total_orders,
        COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
        SUM(oi.price) AS revenue
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp < '2018-09-01'
    GROUP BY 1
)

SELECT
    month,
    total_orders,
    unique_customers,
    ROUND(revenue::numeric, 2) AS revenue,
    ROUND(
        revenue / NULLIF(total_orders, 0),
        2
    ) AS average_order_value,
    ROUND(
        (
            revenue - LAG(revenue) OVER (ORDER BY month)
        )
        / NULLIF(LAG(revenue) OVER (ORDER BY month), 0)
        * 100,
        2
    ) AS revenue_mom_growth_pct,
    ROUND(
        (
            revenue - LAG(revenue, 12) OVER (ORDER BY month)
        )
        / NULLIF(LAG(revenue, 12) OVER (ORDER BY month), 0)
        * 100,
        2
    ) AS revenue_yoy_growth_pct
FROM monthly_sales
ORDER BY month;