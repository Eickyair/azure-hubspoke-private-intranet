INSERT INTO products (
    sku,
    name,
    description,
    category,
    price,
    stock,
    image_blob,
    is_active
) VALUES
    ('NW-ELEC-001', 'Monitor 27'''' 4K', 'Monitor profesional IPS 4K con colores precisos', 'Electronica', 299.99, 45, NULL, TRUE),
    ('NW-ELEC-002', 'Teclado Mecanico RGB', 'Teclado switches red silenciosos', 'Electronica', 89.50, 120, NULL, TRUE),
    ('NW-OFFI-001', 'Silla Ergonomica', 'Silla de malla transpirable con soporte lumbar', 'Oficina', 149.00, 30, NULL, TRUE),
    ('NW-OFFI-002', 'Escritorio Ajustable', 'Escritorio standing desk motorizado', 'Oficina', 350.00, 15, NULL, TRUE),
    ('NW-CLEAN-001', 'Kit Limpieza Pantallas', 'Spray antiestatico y pano de microfibra', 'Limpieza', 12.99, 200, NULL, TRUE)
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    description = VALUES(description),
    category = VALUES(category),
    price = VALUES(price),
    stock = VALUES(stock),
    image_blob = VALUES(image_blob),
    is_active = VALUES(is_active);

INSERT INTO sales_history (
    product_id,
    quantity,
    unit_price,
    sale_date,
    customer_region
)
SELECT p.id, sale.quantity, sale.unit_price, sale.sale_date, sale.customer_region
FROM products p
JOIN (
    SELECT 'NW-ELEC-001' AS sku, 2 AS quantity, 299.99 AS unit_price, TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)) AS sale_date, 'Norte' AS customer_region
    UNION ALL SELECT 'NW-ELEC-002', 5, 89.50, TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)), 'Centro'
    UNION ALL SELECT 'NW-OFFI-001', 1, 149.00, CURRENT_TIMESTAMP, 'Sur'
) sale ON sale.sku = p.sku
WHERE NOT EXISTS (
    SELECT 1
    FROM sales_history sh
    WHERE sh.product_id = p.id
      AND sh.quantity = sale.quantity
      AND sh.unit_price = sale.unit_price
      AND sh.customer_region = sale.customer_region
);