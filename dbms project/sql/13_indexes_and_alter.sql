-- 13_indexes_and_alter.sql  (DDL: CREATE INDEX, ALTER TABLE, DROP)
-- Primary keys, UNIQUE keys and foreign keys already create indexes. These are the extra ones
-- that speed up the queries the app runs.
-- Re-running this file fails on the CREATE INDEX lines if the indexes already exist (MySQL has no IF NOT EXISTS for indexes).

USE hotel_mgmt;

-- Looking up the current/latest stay of a customer, and the stays in a room.
CREATE INDEX idx_stay_customer_status ON stay (customer_id, status);
CREATE INDEX idx_stay_room_status     ON stay (room_number, status);
-- Summing a stay's room-service orders; revenue by date.
CREATE INDEX idx_room_service_stay    ON room_service (stay_id);
CREATE INDEX idx_room_service_date    ON room_service (order_date);
-- Searching people by name.
CREATE INDEX idx_person_name          ON person (name);

-- ALTER TABLE: add a constraint after the table exists.
ALTER TABLE person
    ADD CONSTRAINT chk_person_email
    CHECK (email IS NULL OR email = '' OR email LIKE '%_@_%');

-- DDL demo: CREATE, ALTER and DROP on a throw-away table.
DROP TABLE IF EXISTS ddl_demo;
CREATE TABLE ddl_demo (id INT PRIMARY KEY, note VARCHAR(20));
ALTER TABLE ddl_demo ADD COLUMN created_on DATE;
ALTER TABLE ddl_demo MODIFY COLUMN note VARCHAR(100) NOT NULL DEFAULT '';
DROP TABLE ddl_demo;
