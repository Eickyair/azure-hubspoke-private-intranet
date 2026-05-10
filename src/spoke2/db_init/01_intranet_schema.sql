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

    FOREIGN KEY (manager_id) REFERENCES employees(id) ON DELETE SET NULL,
    INDEX idx_department (department),
    INDEX idx_location (location),
    INDEX idx_hire_date (hire_date),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
