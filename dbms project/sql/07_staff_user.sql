-- 07_staff_user.sql  (DDL)
-- Login accounts (replaces the old `user` table). The role column splits staff into Owner / Receptionist
-- (specialization by role) so the Owner panel can be protected.
-- Passwords are stored as SHA-256 hex (64 chars), never plain text.
-- LIMITATION: unsalted SHA-256 is acceptable for a course project, not for production (use bcrypt/argon2 in the app).

USE hotel_mgmt;

CREATE TABLE IF NOT EXISTS staff_user (
    user_id       INT          NOT NULL AUTO_INCREMENT,
    username      VARCHAR(100) NOT NULL,
    password_hash CHAR(64)     NOT NULL,
    role          VARCHAR(20)  NOT NULL,
    PRIMARY KEY (user_id),
    UNIQUE KEY uq_staff_username (username),
    CONSTRAINT chk_staff_role CHECK (role IN ('Owner', 'Receptionist'))
) ENGINE=InnoDB;
