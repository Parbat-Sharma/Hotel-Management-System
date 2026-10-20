-- 04_customer.sql  (DDL)
-- ER: SPECIALIZATION of PERSON (a customer IS a person). Disjoint: a person is in at most one subtype table.
-- The old `customer` table mixed guest data with room/stay data; the stay part moved to table `stay` (09).

USE hotel_mgmt;

CREATE TABLE IF NOT EXISTS customer (
    person_id     INT  NOT NULL,
    registered_on DATE NOT NULL DEFAULT (CURRENT_DATE),
    PRIMARY KEY (person_id),
    CONSTRAINT fk_customer_person FOREIGN KEY (person_id) REFERENCES person (person_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;
