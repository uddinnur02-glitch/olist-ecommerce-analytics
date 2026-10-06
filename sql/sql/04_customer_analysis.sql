-- ==========================================
-- OLIST CUSTOMER ANALYSIS
-- ==========================================

-- 1. CUSTOMER ORDER FREQUENCY
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT
    total_orders,
    COUNT(*) AS customer_count
FROM customer_orders
GROUP BY total_orders
ORDER BY total_orders;

-- 2. REPEAT CUSTOMER RATE
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT
    COUNT(*) AS total_customers,
    COUNT(*) FILTER (WHERE total_orders > 1) AS repeat_customers,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE total_orders > 1)
        / COUNT(*),
        2
    ) AS repeat_customer_rate_pct
FROM customer_orders;


-- 3. REVENUE FROM REPEAT VS ONE-TIME CUSTOMERS
WITH customer_summary AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.price) AS customer_revenue
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT
    CASE
        WHEN total_orders = 1 THEN 'One-time Customer'
        ELSE 'Repeat Customer'
    END AS customer_type,

    COUNT(*) AS customers,

    ROUND(SUM(customer_revenue)::numeric, 2) AS revenue,

    ROUND(
        100.0 * SUM(customer_revenue)
        / SUM(SUM(customer_revenue)) OVER (),
        2
    ) AS revenue_share_pct

FROM customer_summary
GROUP BY customer_type
ORDER BY revenue DESC;


-- ==========================================
-- 4. RFM CUSTOMER SEGMENTATION
-- ==========================================

WITH customer_rfm AS (
    SELECT
        c.customer_unique_id,

        -- Recency:
        -- days since customer's most recent purchase
        (
            DATE '2018-09-01'
            - MAX(o.order_purchase_timestamp::date)
        ) AS recency_days,

        -- Frequency:
        COUNT(DISTINCT o.order_id) AS frequency,

        -- Monetary:
        SUM(oi.price) AS monetary

    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp < '2018-09-01'

    GROUP BY c.customer_unique_id
),

rfm_scores AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,

        NTILE(5) OVER (
            ORDER BY recency_days DESC
        ) AS recency_score,

        NTILE(5) OVER (
            ORDER BY frequency
        ) AS frequency_score,

        NTILE(5) OVER (
            ORDER BY monetary
        ) AS monetary_score

    FROM customer_rfm
)

SELECT
    customer_unique_id,
    recency_days,
    frequency,
    ROUND(monetary::numeric, 2) AS monetary,
    recency_score,
    frequency_score,
    monetary_score,
    CONCAT(
        recency_score,
        frequency_score,
        monetary_score
    ) AS rfm_score
FROM rfm_scores
ORDER BY
    recency_score DESC,
    frequency_score DESC,
    monetary_score DESC;

-- ==========================================
-- 5. BUSINESS-ORIENTED CUSTOMER SEGMENTATION
-- ==========================================

WITH customer_metrics AS (
    SELECT
        c.customer_unique_id,

        DATE '2018-09-01'
            - MAX(o.order_purchase_timestamp::date)
            AS recency_days,

        COUNT(DISTINCT o.order_id) AS frequency,

        SUM(oi.price) AS monetary

    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp < '2018-09-01'

    GROUP BY c.customer_unique_id
),

customer_scores AS (
    SELECT
        *,
        NTILE(5) OVER (
            ORDER BY monetary
        ) AS monetary_score
    FROM customer_metrics
),

customer_segments AS (
    SELECT
        *,

        CASE
            WHEN frequency >= 2
                 AND recency_days <= 60
                 AND monetary_score >= 4
                THEN 'Champions'

            WHEN frequency >= 2
                 AND recency_days <= 180
                THEN 'Loyal Customers'

            WHEN frequency = 1
                 AND recency_days <= 60
                THEN 'New Customers'

            WHEN frequency >= 2
                 AND recency_days > 180
                THEN 'At Risk'

            WHEN frequency = 1
                 AND recency_days BETWEEN 61 AND 180
                 AND monetary_score >= 4
                THEN 'High-Value Potential'

            WHEN frequency = 1
                 AND recency_days BETWEEN 61 AND 180
                THEN 'Promising'

            ELSE 'Inactive / Low Value'
        END AS customer_segment

    FROM customer_scores
)

SELECT
    customer_segment,
    COUNT(*) AS customers,

    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_share_pct,

    ROUND(
        SUM(monetary)::numeric,
        2
    ) AS revenue,

    ROUND(
        AVG(monetary)::numeric,
        2
    ) AS avg_customer_value

FROM customer_segments
GROUP BY customer_segment
ORDER BY revenue DESC;