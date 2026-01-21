PRAGMA foreign_keys = ON;

-- --------- SAFETY (only matters if you re-run) ----------
DROP TABLE IF EXISTS refunds;
DROP TABLE IF EXISTS returns;
DROP TABLE IF EXISTS shipments;
DROP TABLE IF EXISTS delivery_slots;
DROP TABLE IF EXISTS delivery_partners;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS product_inventory;
DROP TABLE IF EXISTS warehouses;
DROP TABLE IF EXISTS vendor_product_listings;
DROP TABLE IF EXISTS vendors;
DROP TABLE IF EXISTS vendor_types;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS product_variants;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS loyalty_ledger;
DROP TABLE IF EXISTS loyalty_accounts;
DROP TABLE IF EXISTS addresses;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS delivery_methods;
DROP TABLE IF EXISTS payment_methods;

-- ========= CRM: Customers & Addresses =========
CREATE TABLE customers (
  customer_id   INTEGER PRIMARY KEY,
  full_name     TEXT NOT NULL,
  email         TEXT NOT NULL UNIQUE,
  phone         TEXT UNIQUE,
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_customers_email ON customers(email);

CREATE TABLE addresses (
  address_id    INTEGER PRIMARY KEY,
  customer_id   INTEGER NOT NULL,
  label         TEXT,
  line1         TEXT NOT NULL,
  city          TEXT NOT NULL,
  province      TEXT NOT NULL,
  postal_code   TEXT NOT NULL,
  country       TEXT NOT NULL DEFAULT 'South Africa',
  is_default    INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0,1)),
  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE
);

CREATE INDEX idx_addresses_customer ON addresses(customer_id);

-- ========= Catalogue: Categories, Products, Variants =========
CREATE TABLE categories (
  category_id   INTEGER PRIMARY KEY,
  name          TEXT NOT NULL UNIQUE,
  parent_id     INTEGER,
  FOREIGN KEY (parent_id) REFERENCES categories(category_id) ON DELETE SET NULL
);

CREATE TABLE products (
  product_id    INTEGER PRIMARY KEY,
  sku           TEXT NOT NULL UNIQUE,
  name          TEXT NOT NULL,
  category_id   INTEGER,
  base_price    REAL NOT NULL CHECK (base_price >= 0),
  weight_kg     REAL NOT NULL DEFAULT 0 CHECK (weight_kg >= 0),
  active        INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE SET NULL
);

CREATE INDEX idx_products_category ON products(category_id);

-- Optional per-product variations (size/color etc.)
CREATE TABLE product_variants (
  variant_id    INTEGER PRIMARY KEY,
  product_id    INTEGER NOT NULL,
  variant_sku   TEXT NOT NULL UNIQUE,
  variant_name  TEXT NOT NULL,            -- e.g., "128GB Black"
  price_delta   REAL NOT NULL DEFAULT 0,  -- add/subtract on base_price
  weight_delta  REAL NOT NULL DEFAULT 0,
  active        INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
  FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
);

CREATE INDEX idx_variants_product ON product_variants(product_id);

-- ========= Marketplace: Vendors & Listings =========
CREATE TABLE vendor_types (
  vendor_type_id INTEGER PRIMARY KEY,
  name           TEXT NOT NULL UNIQUE    -- e.g., "Brand", "Reseller", "3PL"
);

CREATE TABLE vendors (
  vendor_id      INTEGER PRIMARY KEY,
  vendor_type_id INTEGER NOT NULL,
  name           TEXT NOT NULL UNIQUE,
  contact_email  TEXT,
  contact_phone  TEXT,
  commission_rate REAL NOT NULL DEFAULT 0.10 CHECK (commission_rate BETWEEN 0 AND 0.5), -- platform fee
  active         INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
  created_at     TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (vendor_type_id) REFERENCES vendor_types(vendor_type_id)
);

CREATE INDEX idx_vendors_type ON vendors(vendor_type_id);

-- A vendor lists a product (and optionally a specific variant) with its own price/sku/stock flag
CREATE TABLE vendor_product_listings (
  listing_id     INTEGER PRIMARY KEY,
  vendor_id      INTEGER NOT NULL,
  product_id     INTEGER NOT NULL,
  variant_id     INTEGER,                 -- NULL = base product
  vendor_sku     TEXT NOT NULL,
  price          REAL NOT NULL CHECK (price >= 0),
  active         INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
  UNIQUE (vendor_id, vendor_sku),
  FOREIGN KEY (vendor_id)  REFERENCES vendors(vendor_id),
  FOREIGN KEY (product_id) REFERENCES products(product_id),
  FOREIGN KEY (variant_id) REFERENCES product_variants(variant_id)
);

CREATE INDEX idx_listings_vendor ON vendor_product_listings(vendor_id);
CREATE INDEX idx_listings_product ON vendor_product_listings(product_id);

-- ========= Inventory & Warehouses =========
CREATE TABLE warehouses (
  warehouse_id  INTEGER PRIMARY KEY,
  name          TEXT NOT NULL,
  city          TEXT NOT NULL,
  province      TEXT NOT NULL
);

CREATE TABLE product_inventory (
  product_id     INTEGER NOT NULL,
  warehouse_id   INTEGER NOT NULL,
  qty_on_hand    INTEGER NOT NULL DEFAULT 0 CHECK (qty_on_hand >= 0),
  reorder_point  INTEGER NOT NULL DEFAULT 0 CHECK (reorder_point >= 0),
  PRIMARY KEY (product_id, warehouse_id),
  FOREIGN KEY (product_id)   REFERENCES products(product_id)   ON DELETE CASCADE,
  FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id) ON DELETE CASCADE
);

CREATE INDEX idx_inv_product ON product_inventory(product_id);

-- ========= Payments (methods) =========
CREATE TABLE payment_methods (
  method_code TEXT PRIMARY KEY,                         -- 'CARD','EFT','COD','WALLET'
  name        TEXT NOT NULL,
  active      INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1))
);

-- ========= Delivery (methods, partners, slots) =========
CREATE TABLE delivery_methods (
  method_code TEXT PRIMARY KEY,                         -- 'STANDARD','EXPRESS','SAME_DAY','ECONOMY'
  name        TEXT NOT NULL,
  base_fee    REAL NOT NULL DEFAULT 0 CHECK (base_fee >= 0),
  active      INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1))
);

CREATE TABLE delivery_partners (
  partner_id    INTEGER PRIMARY KEY,
  name          TEXT NOT NULL UNIQUE,
  service_level TEXT NOT NULL REFERENCES delivery_methods(method_code)
);

CREATE TABLE delivery_slots (
  slot_id      INTEGER PRIMARY KEY,
  partner_id   INTEGER,
  window_start TEXT NOT NULL,
  window_end   TEXT NOT NULL,
  capacity     INTEGER NOT NULL CHECK (capacity >= 0),
  FOREIGN KEY (partner_id) REFERENCES delivery_partners(partner_id) ON DELETE SET NULL
);

-- ========= Orders =========
CREATE TABLE orders (
  order_id             INTEGER PRIMARY KEY,
  order_number         TEXT NOT NULL UNIQUE,
  customer_id          INTEGER NOT NULL,
  shipping_address_id  INTEGER NOT NULL,
  delivery_method      TEXT NOT NULL REFERENCES delivery_methods(method_code),
  status TEXT NOT NULL CHECK (status IN
      ('PENDING','PAID','FULFILLING','SHIPPED','DELIVERED','CANCELLED','RETURNED')),
  order_date      TEXT NOT NULL DEFAULT (datetime('now')),
  subtotal        REAL NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
  discount        REAL NOT NULL DEFAULT 0 CHECK (discount >= 0),
  tax             REAL NOT NULL DEFAULT 0 CHECK (tax >= 0),
  shipping_fee    REAL NOT NULL DEFAULT 0 CHECK (shipping_fee >= 0),
  total           REAL NOT NULL CHECK (total >= 0),
  payment_status  TEXT NOT NULL CHECK (payment_status IN ('UNPAID','PARTIAL','PAID','REFUNDED')),
  FOREIGN KEY (customer_id)         REFERENCES customers(customer_id),
  FOREIGN KEY (shipping_address_id) REFERENCES addresses(address_id)
);

CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(status);

CREATE TABLE order_items (
  order_item_id INTEGER PRIMARY KEY,
  order_id      INTEGER NOT NULL,
  product_id    INTEGER NOT NULL,
  variant_id    INTEGER,               -- snapshot which variant was bought
  vendor_id     INTEGER,               -- snapshot which vendor fulfilled this line
  qty           INTEGER NOT NULL CHECK (qty > 0),
  unit_price    REAL NOT NULL CHECK (unit_price >= 0),
  line_total    REAL NOT NULL CHECK (line_total >= 0),
  FOREIGN KEY (order_id)   REFERENCES orders(order_id)   ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products(product_id),
  FOREIGN KEY (variant_id) REFERENCES product_variants(variant_id),
  FOREIGN KEY (vendor_id)  REFERENCES vendors(vendor_id)
);

CREATE INDEX idx_order_items_order ON order_items(order_id);

CREATE TABLE payments (
  payment_id INTEGER PRIMARY KEY,
  order_id   INTEGER NOT NULL,
  method     TEXT NOT NULL REFERENCES payment_methods(method_code),
  amount     REAL NOT NULL CHECK (amount >= 0),
  status TEXT NOT NULL CHECK (status IN ('PENDING','SUCCESS','FAILED','REFUNDED')),
  paid_at TEXT,
  txn_ref TEXT UNIQUE,
  FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);

-- ========= Shipments =========
CREATE TABLE shipments (
  shipment_id  INTEGER PRIMARY KEY,
  order_id     INTEGER NOT NULL,
  warehouse_id INTEGER NOT NULL,
  partner_id   INTEGER NOT NULL,
  tracking_no  TEXT UNIQUE,
  status TEXT NOT NULL CHECK (status IN ('READY','IN_TRANSIT','DELIVERED','DELAYED','LOST','RETURNED')),
  shipped_at   TEXT,
  delivered_at TEXT,
  slot_id      INTEGER,
  FOREIGN KEY (order_id)     REFERENCES orders(order_id)     ON DELETE CASCADE,
  FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id),
  FOREIGN KEY (partner_id)   REFERENCES delivery_partners(partner_id),
  FOREIGN KEY (slot_id)      REFERENCES delivery_slots(slot_id)
);

CREATE INDEX idx_shipments_status ON shipments(status);

-- ========= Returns & Refunds =========
CREATE TABLE returns (
  return_id     INTEGER PRIMARY KEY,
  order_id      INTEGER NOT NULL,
  order_item_id INTEGER,
  reason        TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('REQUESTED','APPROVED','RECEIVED','REJECTED','REFUNDED')),
  requested_at  TEXT NOT NULL DEFAULT (datetime('now')),
  received_at   TEXT,
  refund_amount REAL NOT NULL DEFAULT 0 CHECK (refund_amount >= 0),
  FOREIGN KEY (order_id)      REFERENCES orders(order_id)           ON DELETE CASCADE,
  FOREIGN KEY (order_item_id) REFERENCES order_items(order_item_id) ON DELETE SET NULL
);

CREATE TABLE refunds (
  refund_id    INTEGER PRIMARY KEY,
  order_id     INTEGER NOT NULL,
  payment_id   INTEGER,
  amount       REAL NOT NULL CHECK (amount >= 0),
  method       TEXT NOT NULL CHECK (method IN ('ORIGINAL','MANUAL','WALLET')),
  status       TEXT NOT NULL CHECK (status IN ('PENDING','PROCESSED','FAILED')),
  processed_at TEXT,
  FOREIGN KEY (order_id)  REFERENCES orders(order_id)   ON DELETE CASCADE,
  FOREIGN KEY (payment_id) REFERENCES payments(payment_id) ON DELETE SET NULL
);

-- ========= Loyalty / CRM =========
CREATE TABLE loyalty_accounts (
  account_id    INTEGER PRIMARY KEY,
  customer_id   INTEGER NOT NULL UNIQUE,
  points_balance INTEGER NOT NULL DEFAULT 0 CHECK (points_balance >= 0),
  tier          TEXT NOT NULL DEFAULT 'STANDARD' CHECK (tier IN ('STANDARD','SILVER','GOLD','PLATINUM')),
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE
);

CREATE TABLE loyalty_ledger (
  ledger_id     INTEGER PRIMARY KEY,
  account_id    INTEGER NOT NULL,
  order_id      INTEGER,
  txn_type      TEXT NOT NULL CHECK (txn_type IN ('EARN','REDEEM','ADJUST')),
  points        INTEGER NOT NULL CHECK (points <> 0),
  note          TEXT,
  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (account_id) REFERENCES loyalty_accounts(account_id) ON DELETE CASCADE,
  FOREIGN KEY (order_id)   REFERENCES orders(order_id) ON DELETE SET NULL
);

-- ========= Seed enumerations (payment & delivery methods) =========
INSERT INTO payment_methods(method_code, name) VALUES
  ('CARD','Credit/Debit Card'),
  ('EFT','Instant EFT'),
  ('COD','Cash on Delivery'),
  ('WALLET','Store Wallet');

INSERT INTO delivery_methods(method_code, name, base_fee) VALUES
  ('STANDARD','Standard (2–5 days)', 75.00),
  ('EXPRESS','Express (1–2 days)', 120.00),
  ('SAME_DAY','Same-day (metro)', 180.00),
  ('ECONOMY','Economy (3–7 days)', 60.00);
