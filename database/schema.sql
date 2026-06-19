-- ============================================================
-- Database schema for the AWS 3-Tier Transaction App
-- Database: MySQL (Amazon RDS)
-- ============================================================
-- Run this AFTER connecting to your RDS instance from the
-- App Tier EC2 server:
--   mysql -h <DB-ENDPOINT> -u admin -p
-- ============================================================

CREATE DATABASE IF NOT EXISTS webappdb;

USE webappdb;

CREATE TABLE IF NOT EXISTS transactions (
    id INT NOT NULL AUTO_INCREMENT,
    amount DECIMAL(10,2),
    description VARCHAR(100),
    PRIMARY KEY (id)
);

-- Optional: insert a test row to confirm everything works
-- INSERT INTO transactions (amount, description) VALUES ('400', 'groceries');
-- SELECT * FROM transactions;
