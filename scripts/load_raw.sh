#!/usr/bin/env bash
# One-time load of the 9 Olist CSVs into ClickHouse's `raw` database, verbatim
# (no renaming/transformation/dedup) - see issue #3. Run from repo root with
# ClickHouse up (`docker compose up -d clickhouse`) and the CSVs in ./data/.
set -euo pipefail

CH="docker compose exec -T clickhouse clickhouse-client -u analytics --password analytics"
DATA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/data"

$CH -q "CREATE DATABASE IF NOT EXISTS raw"

$CH -n -q "
CREATE TABLE IF NOT EXISTS raw.customers (
    customer_id Nullable(String),
    customer_unique_id Nullable(String),
    customer_zip_code_prefix Nullable(String),
    customer_city Nullable(String),
    customer_state Nullable(String)
) ENGINE = MergeTree ORDER BY tuple();

CREATE TABLE IF NOT EXISTS raw.geolocation (
    geolocation_zip_code_prefix Nullable(String),
    geolocation_lat Nullable(String),
    geolocation_lng Nullable(String),
    geolocation_city Nullable(String),
    geolocation_state Nullable(String)
) ENGINE = MergeTree ORDER BY tuple();

CREATE TABLE IF NOT EXISTS raw.order_items (
    order_id Nullable(String),
    order_item_id Nullable(String),
    product_id Nullable(String),
    seller_id Nullable(String),
    shipping_limit_date Nullable(String),
    price Nullable(String),
    freight_value Nullable(String)
) ENGINE = MergeTree ORDER BY tuple();

CREATE TABLE IF NOT EXISTS raw.order_payments (
    order_id Nullable(String),
    payment_sequential Nullable(String),
    payment_type Nullable(String),
    payment_installments Nullable(String),
    payment_value Nullable(String)
) ENGINE = MergeTree ORDER BY tuple();

CREATE TABLE IF NOT EXISTS raw.order_reviews (
    review_id Nullable(String),
    order_id Nullable(String),
    review_score Nullable(String),
    review_comment_title Nullable(String),
    review_comment_message Nullable(String),
    review_creation_date Nullable(String),
    review_answer_timestamp Nullable(String)
) ENGINE = MergeTree ORDER BY tuple();

CREATE TABLE IF NOT EXISTS raw.orders (
    order_id Nullable(String),
    customer_id Nullable(String),
    order_status Nullable(String),
    order_purchase_timestamp Nullable(String),
    order_approved_at Nullable(String),
    order_delivered_carrier_date Nullable(String),
    order_delivered_customer_date Nullable(String),
    order_estimated_delivery_date Nullable(String)
) ENGINE = MergeTree ORDER BY tuple();

CREATE TABLE IF NOT EXISTS raw.products (
    product_id Nullable(String),
    product_category_name Nullable(String),
    product_name_lenght Nullable(String),
    product_description_lenght Nullable(String),
    product_photos_qty Nullable(String),
    product_weight_g Nullable(String),
    product_length_cm Nullable(String),
    product_height_cm Nullable(String),
    product_width_cm Nullable(String)
) ENGINE = MergeTree ORDER BY tuple();

CREATE TABLE IF NOT EXISTS raw.sellers (
    seller_id Nullable(String),
    seller_zip_code_prefix Nullable(String),
    seller_city Nullable(String),
    seller_state Nullable(String)
) ENGINE = MergeTree ORDER BY tuple();

CREATE TABLE IF NOT EXISTS raw.product_category_name_translation (
    product_category_name Nullable(String),
    product_category_name_english Nullable(String)
) ENGINE = MergeTree ORDER BY tuple();
"

load() {
    local file="$1" table="$2"
    echo "Loading $file -> raw.$table"
    $CH -q "INSERT INTO raw.$table FORMAT CSVWithNames" < "$DATA_DIR/$file"
}

load olist_customers_dataset.csv customers
load olist_geolocation_dataset.csv geolocation
load olist_order_items_dataset.csv order_items
load olist_order_payments_dataset.csv order_payments
load olist_order_reviews_dataset.csv order_reviews
load olist_orders_dataset.csv orders
load olist_products_dataset.csv products
load olist_sellers_dataset.csv sellers

# This file ships with a UTF-8 BOM; strip it so ClickHouse doesn't fold it
# into the first column name and reject the header.
echo "Loading product_category_name_translation.csv -> raw.product_category_name_translation"
tail -c +4 "$DATA_DIR/product_category_name_translation.csv" | $CH -q "INSERT INTO raw.product_category_name_translation FORMAT CSVWithNames"

echo "Done. Row counts:"
$CH -q "
SELECT 'customers', count() FROM raw.customers
UNION ALL SELECT 'geolocation', count() FROM raw.geolocation
UNION ALL SELECT 'order_items', count() FROM raw.order_items
UNION ALL SELECT 'order_payments', count() FROM raw.order_payments
UNION ALL SELECT 'order_reviews', count() FROM raw.order_reviews
UNION ALL SELECT 'orders', count() FROM raw.orders
UNION ALL SELECT 'products', count() FROM raw.products
UNION ALL SELECT 'sellers', count() FROM raw.sellers
UNION ALL SELECT 'product_category_name_translation', count() FROM raw.product_category_name_translation
FORMAT PrettyCompact
"
