INSERT INTO employees (
    first_name,
    last_name,
    position,
    department,
    email,
    profile_picture_blob_name,
    document_blob_name,
    is_active
) VALUES
    ('Carlos', 'Mendoza', 'Gerente de Logistica', 'Operaciones', 'cmendoza@northwind.lab', 'carlos_mendoza.png', 'carlos_contrato.pdf', TRUE),
    ('Ana', 'Garcia', 'Analista de Datos', 'TI', 'agarcia@northwind.lab', 'ana_garcia.png', 'ana_certificacion.pdf', TRUE),
    ('Luis', 'Fernandez', 'Director de Ventas', 'Comercial', 'lfernandez@northwind.lab', NULL, NULL, TRUE)
ON DUPLICATE KEY UPDATE
    first_name = VALUES(first_name),
    last_name = VALUES(last_name),
    position = VALUES(position),
    department = VALUES(department),
    profile_picture_blob_name = VALUES(profile_picture_blob_name),
    document_blob_name = VALUES(document_blob_name),
    is_active = VALUES(is_active);