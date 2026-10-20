-- 06_driver.sql  (DDL)
-- ER: SPECIALIZATION of PERSON (pick-up service drivers).

USE hotel_mgmt;

CREATE TABLE IF NOT EXISTS driver (
    person_id    INT          NOT NULL,
    car_model    VARCHAR(100) NOT NULL,
    availability VARCHAR(30)  NOT NULL DEFAULT 'Available',
    location     VARCHAR(100),
    PRIMARY KEY (person_id),
    CONSTRAINT chk_driver_availability CHECK (availability IN ('Available', 'On Trip', 'Off Duty')),
    CONSTRAINT fk_driver_person FOREIGN KEY (person_id) REFERENCES person (person_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;
