INSERT INTO dim_country (name)
SELECT DISTINCT customer_country FROM raw_data WHERE customer_country IS NOT NULL AND customer_country != ''
UNION
SELECT DISTINCT seller_country FROM raw_data WHERE seller_country IS NOT NULL AND seller_country != ''
UNION
SELECT DISTINCT store_country FROM raw_data WHERE store_country IS NOT NULL AND store_country != ''
UNION
SELECT DISTINCT supplier_country FROM raw_data WHERE supplier_country IS NOT NULL AND supplier_country != '';

INSERT INTO dim_city (name, state, country_id)
SELECT DISTINCT 
    COALESCE(NULLIF(r.store_city, ''), '(unknown)'),
    COALESCE(NULLIF(r.store_state, ''), '(unknown)'),
    c.country_id
FROM raw_data r
JOIN dim_country c ON COALESCE(NULLIF(r.store_country, ''), '(unknown)') = c.name
WHERE r.store_city IS NOT NULL AND r.store_city != ''
UNION
SELECT DISTINCT 
    COALESCE(NULLIF(r.supplier_city, ''), '(unknown)'),
    '(unknown)',
    c.country_id
FROM raw_data r
JOIN dim_country c ON COALESCE(NULLIF(r.supplier_country, ''), '(unknown)') = c.name
WHERE r.supplier_city IS NOT NULL AND r.supplier_city != '';

INSERT INTO dim_category (name)
SELECT DISTINCT product_category
FROM raw_data
WHERE product_category IS NOT NULL AND product_category != '';

INSERT INTO dim_customer (customer_id, first_name, last_name, age, email, postal_code, pet_type, pet_name, pet_breed, country_id)
SELECT DISTINCT ON (r.file_id, r.sale_customer_id)
    (r.file_id::INTEGER * 100000) + r.sale_customer_id::INTEGER AS customer_id,
    r.customer_first_name,
    r.customer_last_name,
    NULLIF(r.customer_age, '')::INTEGER,
    r.customer_email,
    r.customer_postal_code,
    r.customer_pet_type,
    r.customer_pet_name,
    r.customer_pet_breed,
    c.country_id
FROM raw_data r
LEFT JOIN dim_country c ON NULLIF(r.customer_country, '') = c.name
WHERE r.sale_customer_id IS NOT NULL AND r.sale_customer_id != '';

INSERT INTO dim_seller (seller_id, first_name, last_name, email, postal_code, country_id)
SELECT DISTINCT ON (r.file_id, r.sale_seller_id)
    (r.file_id::INTEGER * 100000) + r.sale_seller_id::INTEGER AS seller_id,
    r.seller_first_name,
    r.seller_last_name,
    r.seller_email,
    r.seller_postal_code,
    c.country_id
FROM raw_data r
LEFT JOIN dim_country c ON NULLIF(r.seller_country, '') = c.name
WHERE r.sale_seller_id IS NOT NULL AND r.sale_seller_id != '';

INSERT INTO dim_product (product_id, name, pet_category, weight, color, size, brand, material, description, rating, reviews, release_date, expiry_date, category_id)
SELECT DISTINCT ON (r.file_id, r.sale_product_id)
    (r.file_id::INTEGER * 100000) + r.sale_product_id::INTEGER AS product_id,
    r.product_name,
    r.pet_category,
    NULLIF(r.product_weight, '')::NUMERIC,
    r.product_color,
    r.product_size,
    r.product_brand,
    r.product_material,
    r.product_description,
    NULLIF(r.product_rating, '')::NUMERIC,
    NULLIF(r.product_reviews, '')::INTEGER,
    TO_DATE(NULLIF(r.product_release_date, ''), 'MM/DD/YYYY'),
    TO_DATE(NULLIF(r.product_expiry_date, ''), 'MM/DD/YYYY'),
    c.category_id
FROM raw_data r
LEFT JOIN dim_category c ON NULLIF(r.product_category, '') = c.name
WHERE r.sale_product_id IS NOT NULL AND r.sale_product_id != '';

INSERT INTO dim_store (store_id, name, location, phone, email, city_id)
SELECT DISTINCT
    (abs(hashtext(COALESCE(r.store_name, '') || '|' || COALESCE(r.store_location, '') || '|' || COALESCE(r.store_city, '') || '|' || COALESCE(r.store_state, '') || '|' || COALESCE(r.store_country, '') || '|' || COALESCE(r.store_phone, '') || '|' || COALESCE(r.store_email, ''))) % 2147483647) AS store_id,
    r.store_name,
    r.store_location,
    r.store_phone,
    r.store_email,
    dc.city_id
FROM raw_data r
LEFT JOIN dim_country co ON COALESCE(NULLIF(r.store_country, ''), '(unknown)') = co.name
LEFT JOIN dim_city dc ON COALESCE(NULLIF(r.store_city, ''), '(unknown)') = dc.name AND COALESCE(NULLIF(r.store_state, ''), '(unknown)') = dc.state AND co.country_id = dc.country_id
WHERE r.store_name IS NOT NULL AND r.store_name != '';

INSERT INTO dim_supplier (supplier_id, name, contact, email, phone, address, city_id)
SELECT DISTINCT
    (abs(hashtext(COALESCE(r.supplier_name, '') || '|' || COALESCE(r.supplier_contact, '') || '|' || COALESCE(r.supplier_email, '') || '|' || COALESCE(r.supplier_phone, '') || '|' || COALESCE(r.supplier_address, '') || '|' || COALESCE(r.supplier_city, '') || '|' || COALESCE(r.supplier_country, ''))) % 2147483647) AS supplier_id,
    r.supplier_name,
    r.supplier_contact,
    r.supplier_email,
    r.supplier_phone,
    r.supplier_address,
    dc.city_id
FROM raw_data r
LEFT JOIN dim_country co ON COALESCE(NULLIF(r.supplier_country, ''), '(unknown)') = co.name
LEFT JOIN dim_city dc ON COALESCE(NULLIF(r.supplier_city, ''), '(unknown)') = dc.name AND dc.state = '(unknown)' AND co.country_id = dc.country_id
WHERE r.supplier_name IS NOT NULL AND r.supplier_name != '';

INSERT INTO fact_sales (sale_id, customer_id, seller_id, product_id, store_id, supplier_id, sale_date, quantity, total_price)
SELECT DISTINCT ON (r.file_id, r.id)
    (r.file_id::INTEGER * 100000) + r.id::INTEGER AS sale_id,
    (r.file_id::INTEGER * 100000) + r.sale_customer_id::INTEGER AS customer_id,
    (r.file_id::INTEGER * 100000) + r.sale_seller_id::INTEGER AS seller_id,
    (r.file_id::INTEGER * 100000) + r.sale_product_id::INTEGER AS product_id,
    (abs(hashtext(COALESCE(r.store_name, '') || '|' || COALESCE(r.store_location, '') || '|' || COALESCE(r.store_city, '') || '|' || COALESCE(r.store_state, '') || '|' || COALESCE(r.store_country, '') || '|' || COALESCE(r.store_phone, '') || '|' || COALESCE(r.store_email, ''))) % 2147483647) AS store_id,
    (abs(hashtext(COALESCE(r.supplier_name, '') || '|' || COALESCE(r.supplier_contact, '') || '|' || COALESCE(r.supplier_email, '') || '|' || COALESCE(r.supplier_phone, '') || '|' || COALESCE(r.supplier_address, '') || '|' || COALESCE(r.supplier_city, '') || '|' || COALESCE(r.supplier_country, ''))) % 2147483647) AS supplier_id,
    TO_DATE(NULLIF(r.sale_date, ''), 'MM/DD/YYYY'),
    NULLIF(r.sale_quantity, '')::INTEGER,
    NULLIF(r.sale_total_price, '')::NUMERIC
FROM raw_data r
WHERE r.id IS NOT NULL AND r.id != '';
