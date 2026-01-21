-- 1) GMV by vendor (last 30 days)
SELECT v.name AS vendor,
       ROUND(SUM(oi.line_total),2) AS gmv
FROM order_items oi
JOIN orders o   ON o.order_id = oi.order_id
JOIN vendors v  ON v.vendor_id = oi.vendor_id
WHERE date(o.order_date) >= date('now','-30 day')
  AND o.status NOT IN ('CANCELLED','RETURNED')
GROUP BY v.vendor_id
ORDER BY gmv DESC;

-- 2) Commission payable to vendors (using vendor-specific commission_rate snapshot)
-- (Assume platform fee withheld from GMV)
SELECT v.name AS vendor,
       ROUND(SUM(oi.line_total * v.commission_rate),2) AS commission_due,
       ROUND(SUM(oi.line_total),2) AS gmv
FROM order_items oi
JOIN orders o  ON o.order_id = oi.order_id
JOIN vendors v ON v.vendor_id = oi.vendor_id
WHERE o.status IN ('PAID','FULFILLING','SHIPPED','DELIVERED')
GROUP BY v.vendor_id
ORDER BY commission_due DESC;

-- 3) Delivery performance: delivered count and average transit hours
WITH delivered AS (
  SELECT * FROM shipments WHERE status='DELIVERED'
)
SELECT COUNT(*) AS delivered_orders,
       ROUND(AVG((julianday(delivered_at)-julianday(shipped_at))*24),2) AS avg_transit_hours
FROM delivered;

-- 4) On-time vs delayed rate by service level (SLA:
-- SAME_DAY=8h, EXPRESS=48h, STANDARD=120h, ECONOMY=168h)

WITH S AS (
  SELECT s.*, dp.service_level
  FROM shipments s
  JOIN delivery_partners dp ON dp.partner_id = s.partner_id
  WHERE s.status = 'DELIVERED'
),
bench AS (
  SELECT dm.method_code AS service_level,
         CASE dm.method_code
           WHEN 'SAME_DAY' THEN 8
           WHEN 'EXPRESS'  THEN 48
           WHEN 'STANDARD' THEN 120
           WHEN 'ECONOMY'  THEN 168
           ELSE 120
         END AS sla_hours
  FROM delivery_methods dm
)
SELECT S.service_level,
       COUNT(*) AS delivered,
       SUM(CASE WHEN (julianday(S.delivered_at) - julianday(S.shipped_at)) * 24 <= b.sla_hours THEN 1 ELSE 0 END) AS on_time,
       ROUND(100.0 * SUM(CASE WHEN (julianday(S.delivered_at) - julianday(S.shipped_at)) * 24 <= b.sla_hours THEN 1 ELSE 0 END) / COUNT(*), 2) AS on_time_pct
FROM S
JOIN bench b ON b.service_level = S.service_level
GROUP BY S.service_level
ORDER BY on_time_pct DESC;


-- 5) Revenue by province
SELECT a.province, ROUND(SUM(o.total),2) AS revenue
FROM orders o
JOIN addresses a ON a.address_id = o.shipping_address_id
WHERE o.status NOT IN ('CANCELLED','RETURNED')
GROUP BY a.province
ORDER BY revenue DESC;

-- 6) Inventory below reorder: actionable replenishment view
SELECT w.name AS warehouse, p.sku, p.name, i.qty_on_hand, i.reorder_point
FROM product_inventory i
JOIN products p   ON p.product_id = i.product_id
JOIN warehouses w ON w.warehouse_id = i.warehouse_id
WHERE i.qty_on_hand < i.reorder_point
ORDER BY w.name, p.sku;

-- 7) Loyalty: points earned this month by customer
SELECT c.full_name,
       COALESCE(SUM(CASE WHEN l.txn_type='EARN'   THEN l.points END),0) AS earned,
       COALESCE(SUM(CASE WHEN l.txn_type='REDEEM' THEN -l.points END),0) AS redeemed,
       la.points_balance AS current_balance
FROM customers c
JOIN loyalty_accounts la ON la.customer_id = c.customer_id
LEFT JOIN loyalty_ledger l ON l.account_id = la.account_id
  AND strftime('%Y-%m', l.created_at) = strftime('%Y-%m', 'now')
GROUP BY c.customer_id
ORDER BY earned DESC;

-- 8) Category performance: top categories by GMV
SELECT cat.name AS category,
       ROUND(SUM(oi.line_total),2) AS gmv
FROM order_items oi
JOIN products p  ON p.product_id = oi.product_id
JOIN categories cat ON cat.category_id = p.category_id
JOIN orders o   ON o.order_id = oi.order_id
WHERE o.status NOT IN ('CANCELLED','RETURNED')
GROUP BY cat.category_id
ORDER BY gmv DESC;

-- 9) Basket analysis: average items per order, AOV
SELECT ROUND(AVG(items_per_order),2) AS avg_items_per_order,
       ROUND(AVG(order_value),2)     AS avg_order_value
FROM (
  SELECT o.order_id,
         SUM(oi.qty) AS items_per_order,
         SUM(oi.line_total) AS order_value
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.order_id
  GROUP BY o.order_id
);
