-- ==========================================
-- OLIST PRODUCT & CATEGORY ANALYSIS
-- ==========================================

-- 1. CATEGORY PERFORMANCE
SELECT
    COALESCE(ct.product_category_name_english,
             p.product_category_name,
             'Unknown') AS category,

    COUNT(DISTINCT oi.order_id) AS orders,

    COUNT(*) AS items_sold,

    ROUND(SUM(oi.price)::numeric, 2) AS revenue,

    ROUND(AVG(oi.price)::numeric, 2) AS avg_item_price,

    ROUND(
        100.0 * SUM(oi.price)
        / SUM(SUM(oi.price)) OVER (),
        2
    ) AS revenue_share_pct

FROM order_items oi
JOIN orders o
    ON oi.order_id = o.order_id
JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name

WHERE o.order_status = 'delivered'

GROUP BY
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    )

ORDER BY revenue DESC;


-- 2. TOP 10 CATEGORIES BY REVENUE


WITH category_sales AS (
    SELECT
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS category,

        COUNT(DISTINCT oi.order_id) AS orders,
        SUM(oi.price) AS revenue

    FROM order_items oi
    JOIN orders o
        ON oi.order_id = o.order_id
    JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN category_translation ct
        ON p.product_category_name = ct.product_category_name

    WHERE o.order_status = 'delivered'

    GROUP BY 1
)

SELECT
    category,
    orders,
    ROUND(revenue::numeric, 2) AS revenue,
    ROUND(
        100.0 * revenue / SUM(revenue) OVER (),
        2
    ) AS revenue_share_pct

FROM category_sales
ORDER BY revenue DESC
LIMIT 10;


-- 3. CATEGORY RANKING

WITH category_sales AS (
    SELECT
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS category,

        SUM(oi.price) AS revenue

    FROM order_items oi
    JOIN orders o
        ON oi.order_id = o.order_id
    JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN category_translation ct
        ON p.product_category_name = ct.product_category_name

    WHERE o.order_status = 'delivered'

    GROUP BY 1
)

SELECT
    category,
    ROUND(revenue::numeric, 2) AS revenue,

    RANK() OVER (
        ORDER BY revenue DESC
    ) AS revenue_rank

FROM category_sales

ORDER BY revenue_rank;

-- ==========================================
-- 4. CATEGORY REVENUE CONCENTRATION
-- ==========================================

WITH category_sales AS (
    SELECT
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS category,

        SUM(oi.price) AS revenue

    FROM order_items oi
    JOIN orders o
        ON oi.order_id = o.order_id
    JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN category_translation ct
        ON p.product_category_name = ct.product_category_name

    WHERE o.order_status = 'delivered'

    GROUP BY 1
),

ranked_categories AS (
    SELECT
        category,
        revenue,

        SUM(revenue) OVER (
            ORDER BY revenue DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_revenue,

        SUM(revenue) OVER () AS total_revenue

    FROM category_sales
)

SELECT
    category,

    ROUND(revenue::numeric, 2) AS revenue,

    ROUND(
        100.0 * revenue / total_revenue,
        2
    ) AS revenue_share_pct,

    ROUND(
        100.0 * cumulative_revenue / total_revenue,
        2
    ) AS cumulative_revenue_pct

FROM ranked_categories

ORDER BY revenue DESC;

-- 5. NUMBER OF CATEGORIES NEEDED TO REACH 80% OF REVENUE

WITH category_sales AS (
    SELECT
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS category,

        SUM(oi.price) AS revenue

    FROM order_items oi
    JOIN orders o
        ON oi.order_id = o.order_id
    JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN category_translation ct
        ON p.product_category_name = ct.product_category_name

    WHERE o.order_status = 'delivered'

    GROUP BY 1
),

ranked_categories AS (
    SELECT
        category,
        revenue,

        ROW_NUMBER() OVER (
            ORDER BY revenue DESC
        ) AS category_rank,

        SUM(revenue) OVER (
            ORDER BY revenue DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_revenue,

        SUM(revenue) OVER () AS total_revenue

    FROM category_sales
)

SELECT
    MIN(category_rank) AS categories_needed_for_80pct
FROM ranked_categories
WHERE
    100.0 * cumulative_revenue / total_revenue >= 80;