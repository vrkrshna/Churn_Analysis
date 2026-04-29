-- ============================================================
-- Purpose: Build customer-level dataset for churn analysis

-- ============================================================

WITH 

-- Step 1: Base table — delivered orders joined with customers
base AS (
    SELECT 
        o.order_id,
        c.customer_unique_id,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),

-- Step 2: Global max date from full delivered set
max_date AS (
    SELECT MAX(order_purchase_timestamp) AS max_date FROM base
),

-- Step 3: Last purchase per customer on full delivered set
last_purchase_per_customer AS (
    SELECT 
        customer_unique_id,
        MAX(order_purchase_timestamp) AS last_purchase
    FROM base
    GROUP BY customer_unique_id
),

-- Step 4+5: Cutoff filter — keep only customers whose last purchase <= cutoff
valid_customers AS (
    SELECT lp.customer_unique_id
    FROM last_purchase_per_customer lp
    CROSS JOIN max_date md
    WHERE lp.last_purchase <= md.max_date - INTERVAL '90 days'
),

-- Step 6: Keep ALL orders for valid customers
filtered_base AS (
    SELECT b.*
    FROM base b
    INNER JOIN valid_customers vc ON b.customer_unique_id = vc.customer_unique_id
),

-- Step 7a: Max date from FILTERED set
-- This is NOT the same as max_date above — it's the max within the filtered population
filtered_max_date AS (
    SELECT MAX(order_purchase_timestamp) AS filtered_max_date
    FROM filtered_base
),

-- Step 7b: Churn label — computed on filtered set using filtered max date
--          churn = date_since_purchase > 90
churn_labels AS (
    SELECT
        fb.customer_unique_id,
        CASE
            WHEN FLOOR(EXTRACT(EPOCH FROM (fmd.filtered_max_date - MAX(fb.order_purchase_timestamp))) / 86400) > 90
            THEN 1 ELSE 0
        END AS churn
    FROM filtered_base fb
    CROSS JOIN filtered_max_date fmd
    GROUP BY fb.customer_unique_id, fmd.filtered_max_date
),

-- Step 8: Window functions — order number and previous order date
orders_ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp
        ) AS order_number,
        LAG(order_purchase_timestamp) OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp
        ) AS prev_order_date
    FROM filtered_base
),

-- Step 9: Compute days_between_orders and delivery_delay per order row
orders_features AS (
    SELECT *,
        EXTRACT(EPOCH FROM (order_purchase_timestamp - prev_order_date)) / 86400
            AS days_between_orders,
        EXTRACT(EPOCH FROM (
            order_delivered_customer_date - order_estimated_delivery_date
        )) / 86400 AS delivery_delay
    FROM orders_ranked
),

-- Step 10: Total orders per customer — from FULL filtered set (before dropna)
total_orders_per_customer AS (
    SELECT 
        customer_unique_id,
        COUNT(order_id)                   AS total_orders,
        MAX(order_purchase_timestamp)     AS last_purchase
    FROM filtered_base
    GROUP BY customer_unique_id
),

-- Step 11: Gap and delay features — only from rows with a prior order
gap_features AS (
    SELECT 
        customer_unique_id,
        AVG(days_between_orders)  AS avg_days_between_orders,
        AVG(delivery_delay)       AS avg_delivery_delay
    FROM orders_features
    WHERE days_between_orders IS NOT NULL
    GROUP BY customer_unique_id
),
category_counts AS (
    SELECT 
        c.customer_unique_id,
        COUNT(DISTINCT p.product_category_name) AS num_categories
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),


-- Step 12: Join total orders + gap features into customer-level table
customer_features AS (
    SELECT
        t.customer_unique_id,
        t.total_orders,
        t.last_purchase,
        g.avg_days_between_orders,
        g.avg_delivery_delay
    FROM total_orders_per_customer t
    LEFT JOIN gap_features g ON t.customer_unique_id = g.customer_unique_id
),
customer_features_enriched AS (
    SELECT 
        cf.*,
        CASE 
            WHEN cc.num_categories > 1 THEN 1
            ELSE 0
        END AS is_multi
    FROM customer_features cf
    LEFT JOIN category_counts cc
        ON cf.customer_unique_id = cc.customer_unique_id
),

-- Step 13: Filter to repeat customers
repeat_customers AS (
    SELECT * FROM customer_features_enriched
    WHERE total_orders > 1
),

-- Step 14: Attach churn label
churn_labeled AS (
    SELECT
        rc.*,
        cl.churn
    FROM repeat_customers rc
    JOIN churn_labels cl ON rc.customer_unique_id = cl.customer_unique_id
)

select * from churn_labeled;
-- Final output
--SELECT churn, COUNT(*) AS customer_count
--FROM churn_labeled
--GROUP BY churn
--ORDER BY churn;