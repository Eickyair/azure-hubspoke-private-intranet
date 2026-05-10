-- ==========================================
-- Spoke 2: Esquema Catalogo de Productos / Intranet Operativa
-- Target: Azure Database for MySQL Flexible Server
-- Ejecutar contra la base Terraform spoke2.app_database_name.
-- ==========================================

CREATE TABLE IF NOT EXISTS products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    sku VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    category VARCHAR(50) NOT NULL,
    price DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    stock INT NOT NULL DEFAULT 0,
    warehouse_location VARCHAR(50) DEFAULT NULL,
    supplier_id VARCHAR(50) DEFAULT NULL,
    image_blob VARCHAR(255) DEFAULT NULL,
    document_blob_name VARCHAR(255) DEFAULT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_audited TIMESTAMP NULL DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_category (category),
    INDEX idx_warehouse (warehouse_location),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS sales_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    total_price DECIMAL(12, 2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    sale_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    customer_region VARCHAR(100) DEFAULT NULL,
    
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT,
    INDEX idx_product_id (product_id),
    INDEX idx_sale_date (sale_date),
    INDEX idx_region (customer_region)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET @schema_name = DATABASE();

SET @sql = IF((SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'products' AND column_name = 'warehouse_location') = 0,
    'ALTER TABLE products ADD COLUMN warehouse_location VARCHAR(50) DEFAULT NULL AFTER stock',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'products' AND column_name = 'supplier_id') = 0,
    'ALTER TABLE products ADD COLUMN supplier_id VARCHAR(50) DEFAULT NULL AFTER warehouse_location',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'products' AND column_name = 'document_blob_name') = 0,
    'ALTER TABLE products ADD COLUMN document_blob_name VARCHAR(255) DEFAULT NULL AFTER image_blob',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'products' AND column_name = 'last_audited') = 0,
    'ALTER TABLE products ADD COLUMN last_audited TIMESTAMP NULL DEFAULT NULL AFTER is_active',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'products' AND column_name = 'created_at') = 0,
    'ALTER TABLE products ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP AFTER last_audited',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'products' AND column_name = 'updated_at') = 0,
    'ALTER TABLE products ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER created_at',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema = @schema_name AND table_name = 'products' AND index_name = 'idx_warehouse') = 0,
    'CREATE INDEX idx_warehouse ON products(warehouse_location)',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
