-- 60_seed_essentials.sql  (DML: INSERT)
-- Data the app needs to be usable at all: the departments and the two login accounts.
-- Safe to run more than once (INSERT IGNORE skips rows that already exist).
--
-- Default logins (CHANGE THE PASSWORDS after first login / in real use):
--   admin     / admin123       role Owner
--   reception / reception123   role Receptionist
-- Passwords are stored hashed (SHA-256), never as plain text.

USE hotel_mgmt;

INSERT IGNORE INTO department (name) VALUES
    ('Front Desk'), ('Management'), ('Accounts'), ('Housekeeping'),
    ('Kitchen'), ('Restaurant'), ('Security');

INSERT IGNORE INTO staff_user (username, password_hash, role) VALUES
    ('admin',     SHA2('admin123', 256),     'Owner'),
    ('reception', SHA2('reception123', 256), 'Receptionist');
