-- 01_database.sql  (DDL)  Creates the new database. The old `hotel` database is NOT touched.
-- Run this first, then 02 .. 13 in numeric order.

CREATE DATABASE IF NOT EXISTS hotel_mgmt
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE hotel_mgmt;
