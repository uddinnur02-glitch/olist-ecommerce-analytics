-- ==========================================
-- OLIST DELIVERY & REVIEW ANALYSIS
-- ==========================================

-- 1. OVERALL DELIVERY PERFORMANCE

SELECT
    COUNT(*) AS delivered_orders,

    ROUND(
        AVG(
            EXTRACT(
                DAY FROM (
                    order_delivered_customer_date
                    - order_purchase_timestamp
                )
            )
        )::numeric,
        2
    ) AS avg_delivery_days,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date
              > order_estimated_delivery_date
    ) AS late_orders,

    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE order_delivered_customer_date
                  > order_estimated_delivery_date
        )
        / COUNT(*),
        2
    ) AS late_delivery_rate_pct

FROM orders

WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;

  
  
  -- 2. DELIVERY PERFORMANCE BY CUSTOMER STATE

SELECT
    c.customer_state,

    COUNT(*) AS delivered_orders,

    ROUND(
        AVG(
            EXTRACT(
                DAY FROM (
                    o.order_delivered_customer_date
                    - o.order_purchase_timestamp
                )
            )
        )::numeric,
        2
    ) AS avg_delivery_days,

    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE o.order_delivered_customer_date
                  > o.order_estimated_delivery_date
        )
        / COUNT(*),
        2
    ) AS late_delivery_rate_pct

FROM orders o

JOIN customers c
    ON o.customer_id = c.customer_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL

GROUP BY c.customer_state

ORDER BY late_delivery_rate_pct DESC;


-- 3. DELIVERY DELAY VS REVIEW SCORE

WITH order_delivery AS (

    SELECT
        o.order_id,

        CASE
            WHEN o.order_delivered_customer_date
                 > o.order_estimated_delivery_date
            THEN 'Late'
            ELSE 'On Time / Early'
        END AS delivery_status

    FROM orders o

    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
),

order_reviews AS (

    SELECT
        order_id,
        AVG(review_score) AS avg_review_score

    FROM reviews

    GROUP BY order_id
)

SELECT
    d.delivery_status,

    COUNT(*) AS orders_with_reviews,

    ROUND(
        AVG(r.avg_review_score)::numeric,
        2
    ) AS average_review_score

FROM order_delivery d

JOIN order_reviews r
    ON d.order_id = r.order_id

GROUP BY d.delivery_status

ORDER BY average_review_score DESC;

-- 4. REVIEW SCORE BY DELIVERY DELAY BUCKET

WITH delivery_reviews AS (
    SELECT
        o.order_id,

        EXTRACT(
            DAY FROM (
                o.order_delivered_customer_date
                - o.order_estimated_delivery_date
            )
        ) AS delay_days,

        r.review_score

    FROM orders o

    JOIN reviews r
        ON o.order_id = r.order_id

    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)

SELECT
    CASE
        WHEN delay_days <= -7 THEN '7+ Days Early'
        WHEN delay_days BETWEEN -6 AND -1 THEN '1-6 Days Early'
        WHEN delay_days = 0 THEN 'On Estimated Date'
        WHEN delay_days BETWEEN 1 AND 3 THEN '1-3 Days Late'
        WHEN delay_days BETWEEN 4 AND 7 THEN '4-7 Days Late'
        ELSE '8+ Days Late'
    END AS delivery_bucket,

    COUNT(*) AS orders,

    ROUND(
        AVG(review_score)::numeric,
        2
    ) AS avg_review_score

FROM delivery_reviews

GROUP BY delivery_bucket

ORDER BY
    MIN(delay_days);


-- 5. LATE DELIVERY RATE AND REVIEW SCORE BY STATE

WITH state_delivery AS (
    SELECT
        c.customer_state,

        o.order_id,

        CASE
            WHEN o.order_delivered_customer_date
                 > o.order_estimated_delivery_date
            THEN 1
            ELSE 0
        END AS is_late,

        r.review_score

    FROM orders o

    JOIN customers c
        ON o.customer_id = c.customer_id

    LEFT JOIN reviews r
        ON o.order_id = r.order_id

    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)

SELECT
    customer_state,

    COUNT(*) AS delivered_orders,

    ROUND(
        100.0 * AVG(is_late)::numeric,
        2
    ) AS late_delivery_rate_pct,

    ROUND(
        AVG(review_score)::numeric,
        2
    ) AS avg_review_score

FROM state_delivery

GROUP BY customer_state

HAVING COUNT(*) >= 100

ORDER BY late_delivery_rate_pct DESC;