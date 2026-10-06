-- ==========================================
-- OLIST SELLER PERFORMANCE ANALYSIS
-- ==========================================

-- 1. SELLER PERFORMANCE OVERVIEW

SELECT
    s.seller_id,
    s.seller_state,

    COUNT(DISTINCT oi.order_id) AS total_orders,

    COUNT(*) AS items_sold,

    ROUND(
        SUM(oi.price)::numeric,
        2
    ) AS revenue,

    ROUND(
        AVG(oi.price)::numeric,
        2
    ) AS avg_item_price

FROM sellers s

JOIN order_items oi
    ON s.seller_id = oi.seller_id

JOIN orders o
    ON oi.order_id = o.order_id

WHERE o.order_status = 'delivered'

GROUP BY
    s.seller_id,
    s.seller_state

ORDER BY revenue DESC;



-- 2. TOP 10 SELLERS BY REVENUE

WITH seller_sales AS (

    SELECT
        s.seller_id,
        s.seller_state,

        COUNT(DISTINCT oi.order_id) AS orders,

        SUM(oi.price) AS revenue

    FROM sellers s

    JOIN order_items oi
        ON s.seller_id = oi.seller_id

    JOIN orders o
        ON oi.order_id = o.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        s.seller_id,
        s.seller_state
)

SELECT
    seller_id,
    seller_state,
    orders,

    ROUND(
        revenue::numeric,
        2
    ) AS revenue,

    ROUND(
        100.0 * revenue
        / SUM(revenue) OVER (),
        2
    ) AS revenue_share_pct

FROM seller_sales

ORDER BY revenue DESC

LIMIT 10;


-- 3. SELLER CONCENTRATION

WITH seller_sales AS (

    SELECT
        s.seller_id,
        SUM(oi.price) AS revenue

    FROM sellers s

    JOIN order_items oi
        ON s.seller_id = oi.seller_id

    JOIN orders o
        ON oi.order_id = o.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY s.seller_id
),

ranked_sellers AS (

    SELECT
        seller_id,
        revenue,

        ROW_NUMBER() OVER (
            ORDER BY revenue DESC
        ) AS seller_rank,

        SUM(revenue) OVER (
            ORDER BY revenue DESC
            ROWS BETWEEN UNBOUNDED PRECEDING
            AND CURRENT ROW
        ) AS cumulative_revenue,

        SUM(revenue) OVER () AS total_revenue

    FROM seller_sales
)

SELECT
    seller_rank,
    seller_id,

    ROUND(
        revenue::numeric,
        2
    ) AS revenue,

    ROUND(
        100.0 * cumulative_revenue
        / total_revenue,
        2
    ) AS cumulative_revenue_pct

FROM ranked_sellers

ORDER BY seller_rank;