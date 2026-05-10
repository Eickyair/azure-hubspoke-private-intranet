-- ==========================================
-- Spoke 2: Esquema Catalogo de Productos
-- Target: Azure Database for MySQL Flexible Server
-- Ejecutar contra la base Terraform spoke2.app_database_name.
-- ==========================================

CREATE TABLE IF NOT EXISTS products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    sku VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    category VARCHAR(50) NOT NULL,
    price FLOAT NOT NULL DEFAULT 0.0,
    stock INT NOT NULL DEFAULT 0,
    image_blob VARCHAR(255) DEFAULT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    
    INDEX idx_category (category),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
