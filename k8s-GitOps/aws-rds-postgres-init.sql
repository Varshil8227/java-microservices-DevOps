-- AWS RDS PostgreSQL Database Initialization Script
--
-- Connect to your AWS RDS PostgreSQL instance using a superuser or master account (e.g. via psql or pgAdmin)
-- and run these commands to pre-create the databases required by the Spring Boot microservices.
-- Note: PostgreSQL does not allow running CREATE DATABASE inside a transaction block or function easily, 
-- so run each line individually or run this script as a batch.

-- 1. Create database for Order Service
CREATE DATABASE "order";

-- 2. Create database for Payment Service
CREATE DATABASE "payment";

-- 3. Create database for Product Service
CREATE DATABASE "product";

-- Verification Command (run in psql to list databases):
-- \l
