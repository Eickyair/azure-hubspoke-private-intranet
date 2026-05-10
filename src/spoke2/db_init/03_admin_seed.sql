INSERT INTO employees (
    first_name,
    last_name,
    position,
    department,
    manager_id,
    hire_date,
    salary,
    location,
    phone_number,
    email,
    profile_picture_blob_name,
    document_blob_name,
    is_active
) VALUES
    ('Carlos', 'Mendoza', 'Gerente de Logistica', 'Operaciones', NULL, '2019-03-15', 65000.00, 'Ciudad de Mexico', '55-1000-2000', 'cmendoza@northwind.lab', 'carlos_mendoza.png', 'carlos_contrato.pdf', TRUE),
    ('Ana', 'Garcia', 'Analista de Datos', 'TI', NULL, '2021-07-01', 32000.00, 'Monterrey', '81-2200-3300', 'agarcia@northwind.lab', 'ana_garcia.png', 'ana_certificacion.pdf', TRUE),
    ('Luis', 'Fernandez', 'Director de Ventas', 'Comercial', NULL, '2017-11-20', 90000.00, 'Guadalajara', '33-4400-5500', 'lfernandez@northwind.lab', NULL, NULL, TRUE)
ON DUPLICATE KEY UPDATE
    first_name = VALUES(first_name),
    last_name = VALUES(last_name),
    position = VALUES(position),
    department = VALUES(department),
    manager_id = VALUES(manager_id),
    hire_date = VALUES(hire_date),
    salary = VALUES(salary),
    location = VALUES(location),
    phone_number = VALUES(phone_number),
    profile_picture_blob_name = VALUES(profile_picture_blob_name),
    document_blob_name = VALUES(document_blob_name),
    is_active = VALUES(is_active);