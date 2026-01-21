PRAGMA foreign_keys = ON;

-- ===== Customers + Addresses (10) =====
INSERT INTO customers(full_name,email,phone) VALUES
('Lerato Mokoena','lerato@example.com','+27-82-000-1111'),
('Sipho Dlamini','sipho@example.com','+27-83-000-2222'),
('Naledi Kgosi','naledi@example.com','+27-74-000-3333'),
('Thabo Ndlovu','thabo@example.com','+27-82-000-4444'),
('Ayanda Zulu','ayanda@example.com','+27-73-000-5555'),
('Samantha Pillay','samantha@example.com','+27-83-000-6666'),
('Bongani Nkosi','bongani@example.com','+27-82-000-7777'),
('Rethabile Mthembu','rethabile@example.com','+27-83-000-8888'),
('Kabelo Molefe','kabelo@example.com','+27-81-000-9999'),
('Nomvula Khumalo','nomvula@example.com','+27-82-111-0000');

-- Randomise domains to gmail/icloud while keeping local-parts
UPDATE customers
SET email = printf(
  '%s@%s',
  substr(email,1,instr(email,'@')-1),
  CASE abs(random()) % 2 WHEN 0 THEN 'gmail.com' ELSE 'icloud.com' END
);

INSERT INTO addresses(customer_id,label,line1,city,province,postal_code,is_default) VALUES
(1,'Home','12 Protea St','Johannesburg','Gauteng','2000',1),
(2,'Home','44 Long St','Cape Town','Western Cape','8000',1),
(3,'Home','11 Main Ave','Durban','KwaZulu-Natal','4001',1),
(4,'Home','22 Sandown Rd','Johannesburg','Gauteng','2196',1),
(5,'Home','7 Palm St','Gqeberha','Eastern Cape','6000',1),
(6,'Home','9 Daisy Rd','Pretoria','Gauteng','0182',1),
(7,'Home','5 Olive Ave','Bloemfontein','Free State','9300',1),
(8,'Home','8 Pine Rd','Nelspruit','Mpumalanga','1200',1),
(9,'Home','4 Willow Dr','Polokwane','Limpopo','0700',1),
(10,'Home','2 Maple St','Kimberley','Northern Cape','8301',1);

-- ===== Categories (7) =====
INSERT INTO categories(name) VALUES
('Electronics'),('Home Appliances'),('Fashion'),('Sports'),
('Books'),('Beauty'),('Toys');

-- ===== Products (8) =====
INSERT INTO products(sku,name,category_id,base_price,weight_kg) VALUES
('SKU-1001','Smartphone X',1,7999,0.25),
('SKU-1002','Bluetooth Earbuds',1,1299,0.05),
('SKU-1003','Laptop Pro 14"',1,15999,1.30),
('SKU-2001','Air Fryer 4L',2,1999,4.8),
('SKU-3001','Men T-Shirt',3,299,0.30),
('SKU-4001','Yoga Mat',4,499,1.50),
('SKU-5001','Novel Book',5,199,0.40),
('SKU-6001','Face Cream',6,259,0.20);

-- Variants (example for Smartphone X)
INSERT INTO product_variants(product_id,variant_sku,variant_name,price_delta,weight_delta) VALUES
(1,'VAR-1001-128B','128GB Black',  0, 0.00),
(1,'VAR-1001-256S','256GB Silver', 800, 0.00);

-- ===== Vendor types & Vendors =====
INSERT INTO vendor_types(name) VALUES ('Brand'),('Reseller'),('3PL');

INSERT INTO vendors(vendor_type_id,name,contact_email,commission_rate) VALUES
(1,'TechSA','ops@techsa.co.za',0.10),
(2,'CapeTraders','support@capetraders.co.za',0.12),
(2,'JoburgGadgets','hello@joburggadgets.co.za',0.15),
(3,'FitGearZA','info@fitgear.co.za',0.10);

-- ===== Vendor Product Listings (link vendor->product/variant + price) =====
INSERT INTO vendor_product_listings(vendor_id,product_id,variant_id,vendor_sku,price) VALUES
(1,1,1,'TSA-SPX-128B',7999),
(1,1,2,'TSA-SPX-256S',8799),
(3,1,1,'JBG-SPX-128B',7899),
(2,3,NULL,'CT-LTP-14',15899),
(2,2,NULL,'CT-EBUD',1199),
(4,6,NULL,'FG-YMAT',499),
(2,4,NULL,'CT-AFRY',1899);

-- ===== Warehouses & Inventory =====
INSERT INTO warehouses(name,city,province) VALUES
('JHB Fulfillment','Johannesburg','Gauteng'),
('CPT Fulfillment','Cape Town','Western Cape'),
('DBN Fulfillment','Durban','KwaZulu-Natal');

INSERT INTO product_inventory(product_id,warehouse_id,qty_on_hand,reorder_point) VALUES
(1,1,60,10),(1,2,30,10),(1,3,20,10),
(2,1,120,15),(2,2,70,15),
(3,1,40,10),(3,2,25,10),
(4,1,35,5),(4,2,25,5),
(6,1,80,10);

-- ===== Delivery partners & slots =====
INSERT INTO delivery_partners(name,service_level) VALUES
('FastTrack Couriers','EXPRESS'),
('Ubuntu Logistics','STANDARD'),
('SA Express','ECONOMY');

INSERT INTO delivery_slots(partner_id,window_start,window_end,capacity) VALUES
(1, datetime('now','+1 day','start of day','+9 hours'),
    datetime('now','+1 day','start of day','+12 hours'), 40),
(2, datetime('now','+1 day','start of day','+12 hours'),
    datetime('now','+1 day','start of day','+17 hours'), 120),
(3, datetime('now','+1 day','start of day','+10 hours'),
    datetime('now','+1 day','start of day','+13 hours'), 80);

-- ===== Orders, Items, Payments, Shipments =====
-- O1: Smartphone 128GB from TechSA, Express
INSERT INTO orders(order_number,customer_id,shipping_address_id,delivery_method,status,
                   subtotal,discount,tax,shipping_fee,total,payment_status)
VALUES ('ORD-0001',1,1,'EXPRESS','DELIVERED', 7999,0,1199.85,120, 9318.85,'PAID');

INSERT INTO order_items(order_id,product_id,variant_id,vendor_id,qty,unit_price,line_total)
VALUES (1,1,1,1,1,7999,7999);

INSERT INTO payments(order_id,method,amount,status,paid_at,txn_ref)
VALUES (1,'CARD',9318.85,'SUCCESS',datetime('now','-3 day'),'TXN-0001');

INSERT INTO shipments(order_id,warehouse_id,partner_id,tracking_no,status,shipped_at,delivered_at,slot_id)
VALUES (1,1,1,'TRK-FT-1001','DELIVERED',datetime('now','-2 day'),datetime('now','-1 day'),1);

-- O2: Laptop from CapeTraders, Standard (in transit)
INSERT INTO orders(order_number,customer_id,shipping_address_id,delivery_method,status,
                   subtotal,discount,tax,shipping_fee,total,payment_status)
VALUES ('ORD-0002',2,2,'STANDARD','SHIPPED', 15899,0,2384.85,75, 18358.85,'PAID');

INSERT INTO order_items(order_id,product_id,variant_id,vendor_id,qty,unit_price,line_total)
VALUES (2,3,NULL,2,1,15899,15899);

INSERT INTO payments(order_id,method,amount,status,paid_at,txn_ref)
VALUES (2,'EFT',18358.85,'SUCCESS',datetime('now','-2 day'),'TXN-0002');

INSERT INTO shipments(order_id,warehouse_id,partner_id,tracking_no,status,shipped_at,delivered_at,slot_id)
VALUES (2,2,2,'TRK-UL-2002','IN_TRANSIT',datetime('now','-1 day'),NULL,2);

-- O3: Yoga Mat from FitGearZA, Economy (ready)
INSERT INTO orders(order_number,customer_id,shipping_address_id,delivery_method,status,
                   subtotal,discount,tax,shipping_fee,total,payment_status)
VALUES ('ORD-0003',3,3,'ECONOMY','PAID', 499,0,74.85,60, 633.85,'PAID');

INSERT INTO order_items(order_id,product_id,variant_id,vendor_id,qty,unit_price,line_total)
VALUES (3,6,NULL,4,1,499,499);

INSERT INTO payments(order_id,method,amount,status,paid_at,txn_ref)
VALUES (3,'COD',633.85,'PENDING',NULL,'TXN-0003');

INSERT INTO shipments(order_id,warehouse_id,partner_id,tracking_no,status,shipped_at,delivered_at,slot_id)
VALUES (3,1,3,'TRK-SA-3003','READY',NULL,NULL,3);

-- ===== Returns & Refunds (example) =====
INSERT INTO returns(order_id,order_item_id,reason,status,refund_amount)
VALUES (2,(SELECT order_item_id FROM order_items WHERE order_id=2 LIMIT 1),
        'Defective screen','APPROVED',0.00);

INSERT INTO refunds(order_id,payment_id,amount,method,status,processed_at)
VALUES (1,(SELECT payment_id FROM payments WHERE order_id=1),'200.00','ORIGINAL','PROCESSED',datetime('now'));

-- ===== Loyalty =====
INSERT INTO loyalty_accounts(customer_id,points_balance,tier) VALUES
(1,100,'SILVER'),(2,50,'STANDARD'),(3,0,'STANDARD');

-- Earn on O1 (assume 1 point per R100 total)
INSERT INTO loyalty_ledger(account_id,order_id,txn_type,points,note)
VALUES
((SELECT account_id FROM loyalty_accounts WHERE customer_id=1),1,'EARN', ROUND(9318.85/100.0), '1pt per R100');

-- Redeem example (customer 1 uses 20 points)
INSERT INTO loyalty_ledger(account_id,order_id,txn_type,points,note)
VALUES
((SELECT account_id FROM loyalty_accounts WHERE customer_id=1),NULL,'REDEEM', -20, 'Manual redemption');

-- Adjust running balance (demo only — normally you’d do via app logic)
UPDATE loyalty_accounts
SET points_balance = points_balance
  + (SELECT COALESCE(SUM(points),0) FROM loyalty_ledger WHERE account_id = loyalty_accounts.account_id);
