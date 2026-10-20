-- 10_room_service.sql  (DDL)
-- ER: STAY 1 --- N ROOM_SERVICE (an order belongs to exactly one stay; total participation of the order).
-- Linked to the stay (not the customer) so each stay is billed separately.

USE hotel_mgmt;

CREATE TABLE IF NOT EXISTS room_service (
    order_id     INT           NOT NULL AUTO_INCREMENT,
    stay_id      INT           NOT NULL,
    service_name VARCHAR(255)  NOT NULL,
    cost         DECIMAL(10,2) NOT NULL,
    order_date   DATE          NOT NULL DEFAULT (CURRENT_DATE),
    PRIMARY KEY (order_id),
    CONSTRAINT chk_room_service_cost CHECK (cost > 0),
    CONSTRAINT fk_room_service_stay FOREIGN KEY (stay_id) REFERENCES stay (stay_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;
