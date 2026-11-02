-- =====================================================================
-- Olist e-commerce analysis (MySQL 8.0+)
-- Database: project1. Tables loaded from the Kaggle Olist CSV files
-- (see notebooks/01_import_data.py for the table names).
-- =====================================================================
USE project1;

-- ---------------------------------------------------------------------
-- 0. Sanity checks
-- ---------------------------------------------------------------------
SELECT COUNT(*) FROM orders;        -- about 99,441
SELECT COUNT(*) FROM order_items;   -- about 112,650
SELECT order_status, COUNT(*) FROM orders GROUP BY order_status;

-- ---------------------------------------------------------------------
-- Q1. Monthly revenue and orders (delivered orders only)
-- ---------------------------------------------------------------------
SELECT DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
       COUNT(DISTINCT o.order_id) AS orders,
       ROUND(SUM(oi.price), 2) AS revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY month
ORDER BY month;

-- ---------------------------------------------------------------------
-- Q2. Revenue and freight by product category (English names).
--     LEFT JOIN keeps products without a category, labeled 'unknown'.
-- ---------------------------------------------------------------------
SELECT COALESCE(NULLIF(t.product_category_name_english, ''), 'unknown') AS category,
       ROUND(SUM(oi.price), 2) AS revenue,
       ROUND(SUM(oi.freight_value), 2) AS freight,
       COUNT(*) AS items_sold
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category t ON p.product_category_name = t.product_category_name
GROUP BY category
ORDER BY revenue DESC
LIMIT 15;

-- ---------------------------------------------------------------------
-- Q3a. Sales by customer state
-- ---------------------------------------------------------------------
SELECT c.customer_state,
       COUNT(DISTINCT o.order_id) AS orders,
       ROUND(SUM(oi.price), 2) AS revenue
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY revenue DESC;

-- Q3b. Top 10 cities
SELECT c.customer_city, c.customer_state,
       COUNT(DISTINCT o.order_id) AS orders,
       ROUND(SUM(oi.price), 2) AS revenue
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_city, c.customer_state
ORDER BY revenue DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- Q4a. Delivery time by review score.
--      Some orders have several reviews: average them per order first,
--      otherwise those orders would be counted twice.
-- ---------------------------------------------------------------------
WITH order_review AS (
  SELECT order_id, AVG(review_score) AS score
  FROM order_reviews
  GROUP BY order_id
)
SELECT ROUND(r.score) AS review_score,
       COUNT(*) AS orders,
       ROUND(AVG(DATEDIFF(o.order_delivered_customer_date,
                          o.order_purchase_timestamp)), 1) AS avg_delivery_days
FROM orders o
JOIN order_review r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY ROUND(r.score)
ORDER BY review_score;

-- Q4b. Late vs. on-time deliveries (headline insight)
WITH order_review AS (
  SELECT order_id, AVG(review_score) AS score
  FROM order_reviews
  GROUP BY order_id
)
SELECT CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 'Late' ELSE 'On time' END AS delivery,
       COUNT(*) AS orders,
       ROUND(AVG(r.score), 2) AS avg_review_score
FROM orders o
JOIN order_review r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY delivery;

-- Q4c. Validation of the Power BI card "Late Delivery %" (expected: about 8.1)
SELECT ROUND(100 * AVG(order_delivered_customer_date > order_estimated_delivery_date), 1) AS pct_late
FROM orders
WHERE order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL;

-- ---------------------------------------------------------------------
-- Q5. RFM segmentation.
--     customer_unique_id identifies a person (customer_id changes per order).
--     Frequency is split in 3 levels because about 97% of customers bought once.
-- ---------------------------------------------------------------------
WITH customer_orders AS (
  SELECT c.customer_unique_id, o.order_id, o.order_purchase_timestamp,
         SUM(oi.price) AS order_value
  FROM orders o
  JOIN customers c ON o.customer_id = c.customer_id
  JOIN order_items oi ON o.order_id = oi.order_id
  WHERE o.order_status = 'delivered'
  GROUP BY c.customer_unique_id, o.order_id, o.order_purchase_timestamp
),
rfm AS (
  SELECT customer_unique_id,
         DATEDIFF((SELECT MAX(order_purchase_timestamp) FROM orders),
                  MAX(order_purchase_timestamp)) AS recency_days,
         COUNT(order_id) AS frequency,
         ROUND(SUM(order_value), 2) AS monetary
  FROM customer_orders
  GROUP BY customer_unique_id
),
scored AS (
  SELECT *,
         NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,  -- 5 = most recent
         NTILE(5) OVER (ORDER BY monetary) AS m_score,           -- 5 = biggest spender
         CASE WHEN frequency = 1 THEN 1 WHEN frequency = 2 THEN 2 ELSE 3 END AS f_score
  FROM rfm
),
segmented AS (
  SELECT *,
         CASE WHEN f_score >= 2 AND r_score >= 3 THEN 'Loyal'
              WHEN r_score >= 4 AND m_score >= 4 THEN 'New high-value'
              WHEN r_score <= 2 AND m_score >= 4 THEN 'At-risk high-value'
              WHEN r_score <= 2 THEN 'Inactive'
              ELSE 'Regular' END AS segment
  FROM scored
)
SELECT segment,
       COUNT(*) AS customers,
       ROUND(SUM(monetary), 2) AS revenue,
       ROUND(AVG(monetary), 2) AS avg_spend
FROM segmented
GROUP BY segment
ORDER BY revenue DESC;

-- ---------------------------------------------------------------------
-- Q6. Seller performance (sellers with at least 30 delivered orders)
--     To list problem sellers, use: ORDER BY avg_review ASC
-- ---------------------------------------------------------------------
WITH order_review AS (
  SELECT order_id, AVG(review_score) AS score
  FROM order_reviews
  GROUP BY order_id
),
seller_orders AS (
  SELECT oi.seller_id, oi.order_id,
         SUM(oi.price) AS revenue,
         MAX(o.order_delivered_customer_date > o.order_estimated_delivery_date) AS is_late
  FROM order_items oi
  JOIN orders o ON oi.order_id = o.order_id
  WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
  GROUP BY oi.seller_id, oi.order_id
)
SELECT so.seller_id, s.seller_state,
       COUNT(*) AS orders,
       ROUND(SUM(so.revenue), 2) AS revenue,
       ROUND(AVG(r.score), 2) AS avg_review,
       ROUND(100 * AVG(so.is_late), 1) AS pct_late
FROM seller_orders so
JOIN sellers s ON so.seller_id = s.seller_id
LEFT JOIN order_review r ON so.order_id = r.order_id
GROUP BY so.seller_id, s.seller_state
HAVING COUNT(*) >= 30
ORDER BY revenue DESC
LIMIT 20;

-- ---------------------------------------------------------------------
-- Q7. Share of customers who ordered only once (expected: about 97%)
-- ---------------------------------------------------------------------
WITH c AS (
  SELECT cu.customer_unique_id, COUNT(DISTINCT o.order_id) AS n_orders
  FROM orders o
  JOIN customers cu ON o.customer_id = cu.customer_id
  WHERE o.order_status = 'delivered'
  GROUP BY cu.customer_unique_id
)
SELECT CASE WHEN n_orders = 1 THEN '1 order' ELSE '2+ orders' END AS buyer_type,
       COUNT(*) AS customers,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM c
GROUP BY buyer_type;