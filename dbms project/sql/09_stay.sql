-- 09_stay.sql  (DDL)
-- ER: resolves the M:N relationship CUSTOMER --- ROOM (a customer can stay in many rooms over time,
-- a room hosts many customers over time). Each row is one stay.
-- Participation: partial on both sides (a customer may exist before/without a stay; a room may never be booked).
-- nightly_rate is copied from room.price at check-in, so later price changes do NOT rewrite old bills.
--
-- active_room is a generated column: it equals room_number only while the stay is 'Checked In', else NULL.
-- The UNIQUE key on it makes it IMPOSSIBLE for the database to hold two active stays in one room
-- (a hard guarantee against double-booking, independent of any application or trigger code).
-- (Because of this generated column, the room FK must not use ON UPDATE CASCADE.)

USE hotel_mgmt;

CREATE TABLE IF NOT EXISTS stay (
    stay_id            INT           NOT NULL AUTO_INCREMENT,
    customer_id        INT           NOT NULL,
    room_number        VARCHAR(20)   NOT NULL,
    check_in           DATE          NOT NULL,
    expected_check_out DATE,
    check_out          DATE,
    nightly_rate       DECIMAL(10,2) NOT NULL,
    status             VARCHAR(20)   NOT NULL DEFAULT 'Checked In',
    active_room        VARCHAR(20) GENERATED ALWAYS AS (IF(status = 'Checked In', room_number, NULL)) STORED,
    PRIMARY KEY (stay_id),
    UNIQUE KEY uq_one_active_stay_per_room (active_room),
    CONSTRAINT chk_stay_status   CHECK (status IN ('Checked In', 'Checked Out')),
    CONSTRAINT chk_stay_rate     CHECK (nightly_rate > 0),
    CONSTRAINT chk_stay_expected CHECK (expected_check_out IS NULL OR expected_check_out >= check_in),
    CONSTRAINT chk_stay_checkout CHECK (check_out IS NULL OR check_out >= check_in),
    CONSTRAINT fk_stay_customer FOREIGN KEY (customer_id) REFERENCES customer (person_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_stay_room FOREIGN KEY (room_number) REFERENCES room (room_number)
        ON DELETE RESTRICT
) ENGINE=InnoDB;
