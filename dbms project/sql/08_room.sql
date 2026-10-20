-- 08_room.sql  (DDL)   (was `add_room`)
-- `availability` is maintained by triggers (30_triggers.sql) from the stay table; do not edit it by hand.
-- Money is DECIMAL (the old DOUBLE gives rounding errors).

USE hotel_mgmt;

CREATE TABLE IF NOT EXISTS room (
    room_number     VARCHAR(20)   NOT NULL,
    bed_type        VARCHAR(30)   NOT NULL DEFAULT 'Single Bed',
    price           DECIMAL(10,2) NOT NULL,
    cleaning_status VARCHAR(30)   NOT NULL DEFAULT 'Cleaned',
    availability    VARCHAR(30)   NOT NULL DEFAULT 'Available',
    PRIMARY KEY (room_number),
    CONSTRAINT chk_room_price        CHECK (price > 0),
    CONSTRAINT chk_room_availability CHECK (availability IN ('Available', 'Occupied')),
    CONSTRAINT chk_room_cleaning     CHECK (cleaning_status IN ('Cleaned', 'Dirty')),
    CONSTRAINT chk_room_bed          CHECK (bed_type IN ('Single Bed', 'Double Bed'))
) ENGINE=InnoDB;
