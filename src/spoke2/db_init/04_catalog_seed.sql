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
    ('LMD-FID-200', 'La Moderna Sopa Fideo', 'Sopa de pasta fideo sazón casero con tomate y pollo. Empaque familiar. 200g', 'Abarrotes', 12.50, 150, NULL, TRUE),
    ('FUD-PAV-450', 'FUD Pechuga de Pavo Virginia', 'Pechuga de pavo Virginia FUD, 26 rebanadas. Empaque bioamigable resellable. 450g', 'Salchichoneria', 85.00, 60, NULL, TRUE),
    ('DJU-70-700', 'Tequila Don Julio 70 Añejo Cristalino', 'Tequila añejo cristalino Don Julio 70, 100% de agave. 700ml', 'Vinos y Licores', 1150.00, 25, NULL, TRUE),
    ('NUT-SOY-946', 'Nutrioli Aceite Comestible', 'Aceite comestible puro de soya Nutrioli con omegas 3, 6 y 9. 946ml', 'Abarrotes', 48.00, 200, NULL, TRUE),
    ('KEL-ZUC-620', 'Kellogg''s Zucaritas', 'Cereal de hojuelas de maíz escarchadas con azúcar. Empaque familiar (Aprox. 20 raciones). 620g', 'Abarrotes', 75.00, 85, NULL, TRUE),
    ('FAB-LAV-2000', 'Fabuloso Frescura Activa Lavanda', 'Limpiador multiusos antibacterial y antiviral, aroma fresca lavanda. 2L', 'Limpieza', 42.00, 120, NULL, TRUE),
    ('LMD-LET-250', 'La Moderna Pasta Letra', 'Pasta de sémola de trigo durum en forma de letras, enriquecida con vitaminas. 250g', 'Abarrotes', 10.00, 180, NULL, TRUE),
    ('BON-LEV-1400', 'Bonafont Levité Pepino-Limón', 'Agua infusionada sabor pepino-limón. 1.4L', 'Bebidas', 22.00, 90, NULL, TRUE),
    ('FUD-PAN-300', 'FUD Queso Panela Rebanado', 'Queso panela rebanado 100% de leche, 10 rebanadas. Empaque bioamigable. 300g', 'Lacteos', 65.00, 40, NULL, TRUE),
    ('ELE-UVA-625', 'Electrolit Suero Rehidratante Uva', 'Solución esterilizada de electrolitos orales sabor uva para tratar la deshidratación. 625ml', 'Farmacia', 32.00, 110, NULL, TRUE)
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    description = VALUES(description),
    category = VALUES(category),
    price = VALUES(price),
    stock = VALUES(stock),
    image_blob = VALUES(image_blob),
    is_active = VALUES(is_active);