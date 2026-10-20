-- 11_invoice.sql  (DDL)
-- ER: STAY 1 --- 1 INVOICE (UNIQUE stay_id).
-- ER: INVOICE_ITEM is a WEAK ENTITY: a line has no identity of its own, only "line N of invoice X".
--     Its primary key is the composite (invoice_id, line_no): the owner's key plus a partial key.
-- An invoice is an intentional SNAPSHOT of the bill at generation time (nights / room_total / service_total),
-- frozen once the guest has checked out.
-- grand_total is a generated column so it can never disagree with room_total + service_total.

USE hotel_mgmt;

CREATE TABLE IF NOT EXISTS invoice (
    invoice_id    INT           NOT NULL AUTO_INCREMENT,
    stay_id       INT           NOT NULL,
    issued_on     DATE          NOT NULL DEFAULT (CURRENT_DATE),
    nights        INT           NOT NULL,
    room_total    DECIMAL(12,2) NOT NULL,
    service_total DECIMAL(12,2) NOT NULL DEFAULT 0,
    grand_total   DECIMAL(12,2) GENERATED ALWAYS AS (room_total + service_total) STORED,
    PRIMARY KEY (invoice_id),
    UNIQUE KEY uq_invoice_stay (stay_id),
    CONSTRAINT chk_invoice_nights CHECK (nights >= 1),
    CONSTRAINT fk_invoice_stay FOREIGN KEY (stay_id) REFERENCES stay (stay_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS invoice_item (
    invoice_id  INT           NOT NULL,
    line_no     INT           NOT NULL,
    description VARCHAR(255)  NOT NULL,
    amount      DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (invoice_id, line_no),
    CONSTRAINT fk_invoice_item_invoice FOREIGN KEY (invoice_id) REFERENCES invoice (invoice_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;
