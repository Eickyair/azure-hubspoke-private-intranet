-- ==========================================
-- Spoke 2: Base de Datos Intranet (Admin)
-- Target: Azure Database for MySQL Flexible Server
-- ==========================================

CREATE DATABASE IF NOT EXISTS intranet_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE intranet_db;

CREATE TABLE IF NOT EXISTS employees (
    id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    position VARCHAR(100) NOT NULL,
    department VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    profile_picture_url VARCHAR(255) DEFAULT NULL,
    document_url VARCHAR(255) DEFAULT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    
    INDEX idx_department (department),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
