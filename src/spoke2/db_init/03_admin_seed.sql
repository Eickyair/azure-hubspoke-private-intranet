INSERT INTO employees (
    first_name,
    last_name,
    position,
    department,
    hire_date,
    email,
    profile_picture_blob_name,
    document_blob_name,
    is_active
) VALUES
    ('Carlos', 'Mendoza', 'Gerente de Logistica', 'Operaciones', '2020-01-01', 'cmendoza@northwind.lab', 'carlos_mendoza.png', 'carlos_contrato.pdf', TRUE),
    ('Ana', 'Garcia', 'Analista de Datos', 'TI', '2020-01-01', 'agarcia@northwind.lab', 'ana_garcia.png', 'ana_certificacion.pdf', TRUE),
    ('Luis', 'Fernandez', 'Director de Ventas', 'Comercial', '2020-01-01', 'lfernandez@northwind.lab', NULL, NULL, TRUE)
ON DUPLICATE KEY UPDATE
    first_name = VALUES(first_name),
    last_name = VALUES(last_name),
    position = VALUES(position),
    department = VALUES(department),
    profile_picture_blob_name = VALUES(profile_picture_blob_name),
    document_blob_name = VALUES(document_blob_name),
    is_active = VALUES(is_active);
