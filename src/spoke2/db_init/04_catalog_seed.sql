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