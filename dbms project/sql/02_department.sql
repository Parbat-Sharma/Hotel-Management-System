-- 02_department.sql  (DDL)
-- ER: Department 1 --- N Employee. Employee has TOTAL participation (every employee belongs to a department).
-- Normalization: the old employee.job was free text repeated on every row; it is now a lookup table.

USE hotel_mgmt;

CREATE TABLE IF NOT EXISTS department (
    dept_id INT          NOT NULL AUTO_INCREMENT,
    name    VARCHAR(60)  NOT NULL,
    PRIMARY KEY (dept_id),
    UNIQUE KEY uq_department_name (name)
) ENGINE=InnoDB;
