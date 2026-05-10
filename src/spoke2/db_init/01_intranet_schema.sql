-- ==========================================
-- Spoke 2: Esquema Admin
-- Target: Azure Database for MySQL Flexible Server
-- Ejecutar contra la base Terraform spoke2.admin_database_name.
-- ==========================================

CREATE TABLE IF NOT EXISTS employees (
    id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    position VARCHAR(100) NOT NULL,
    department VARCHAR(100) NOT NULL,
    manager_id INT DEFAULT NULL,
    hire_date DATE NOT NULL,
    salary DECIMAL(12, 2) DEFAULT NULL,
    location VARCHAR(100) DEFAULT NULL,
    phone_number VARCHAR(50) DEFAULT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    profile_picture_blob_name VARCHAR(255) DEFAULT NULL,
    document_blob_name VARCHAR(255) DEFAULT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_employees_manager FOREIGN KEY (manager_id) REFERENCES employees(id) ON DELETE SET NULL,
    INDEX idx_department (department),
    INDEX idx_location (location),
    INDEX idx_hire_date (hire_date),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET @schema_name = DATABASE();

SET @sql = IF((SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'employees' AND column_name = 'manager_id') = 0,
    'ALTER TABLE employees ADD COLUMN manager_id INT DEFAULT NULL AFTER department',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = IF((SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'employees' AND column_name = 'hire_date') = 0,
    "ALTER TABLE employees ADD COLUMN hire_date DATE NOT NULL DEFAULT '2020-01-01' AFTER manager_id",
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'employees' AND column_name = 'salary') = 0,
    'ALTER TABLE employees ADD COLUMN salary DECIMAL(12, 2) DEFAULT NULL AFTER hire_date',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'employees' AND column_name = 'location') = 0,
    'ALTER TABLE employees ADD COLUMN location VARCHAR(100) DEFAULT NULL AFTER salary',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'employees' AND column_name = 'phone_number') = 0,
    'ALTER TABLE employees ADD COLUMN phone_number VARCHAR(50) DEFAULT NULL AFTER location',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'employees' AND column_name = 'profile_picture_blob_name') = 0,
    'ALTER TABLE employees ADD COLUMN profile_picture_blob_name VARCHAR(255) DEFAULT NULL AFTER email',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'employees' AND column_name = 'document_blob_name') = 0,
    'ALTER TABLE employees ADD COLUMN document_blob_name VARCHAR(255) DEFAULT NULL AFTER profile_picture_blob_name',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'employees' AND column_name = 'created_at') = 0,
    'ALTER TABLE employees ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP AFTER is_active',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = @schema_name AND table_name = 'employees' AND column_name = 'updated_at') = 0,
    'ALTER TABLE employees ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER created_at',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema = @schema_name AND table_name = 'employees' AND index_name = 'idx_location') = 0,
    'CREATE INDEX idx_location ON employees(location)',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema = @schema_name AND table_name = 'employees' AND index_name = 'idx_hire_date') = 0,
    'CREATE INDEX idx_hire_date ON employees(hire_date)',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
