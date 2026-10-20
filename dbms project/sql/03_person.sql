-- 03_person.sql  (DDL)
-- ER: GENERALIZATION. Customer, Employee and Driver all share name/phone/email/gender/age,
-- so these attributes live once in the supertype PERSON (bottom-up generalization).
-- The three subtype tables (04, 05, 06) use person_id as both primary key and foreign key.

USE hotel_mgmt;

CREATE TABLE IF NOT EXISTS person (
    person_id INT          NOT NULL AUTO_INCREMENT,
    name      VARCHAR(100) NOT NULL,
    phone     VARCHAR(20),
    email     VARCHAR(100),
    gender    VARCHAR(20),
    age       INT,
    PRIMARY KEY (person_id),
    CONSTRAINT chk_person_age CHECK (age IS NULL OR age BETWEEN 0 AND 120)
) ENGINE=InnoDB;
