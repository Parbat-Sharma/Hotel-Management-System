-- 05_employee.sql  (DDL)
-- ER: SPECIALIZATION of PERSON, plus N:1 to DEPARTMENT (total participation: dept_id is NOT NULL).
-- ON DELETE RESTRICT on dept_id: a department that still has employees cannot be deleted.

USE hotel_mgmt;

CREATE TABLE IF NOT EXISTS employee (
    person_id INT           NOT NULL,
    dept_id   INT           NOT NULL,
    salary    DECIMAL(10,2),
    aadhaar   CHAR(12)      NOT NULL,
    hire_date DATE          NOT NULL DEFAULT (CURRENT_DATE),
    PRIMARY KEY (person_id),
    UNIQUE KEY uq_employee_aadhaar (aadhaar),
    CONSTRAINT chk_employee_salary CHECK (salary IS NULL OR salary > 0),
    CONSTRAINT fk_employee_person FOREIGN KEY (person_id) REFERENCES person (person_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_employee_department FOREIGN KEY (dept_id) REFERENCES department (dept_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;
