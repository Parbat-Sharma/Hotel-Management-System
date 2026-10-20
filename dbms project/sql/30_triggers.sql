-- 30_triggers.sql  (TRIGGERS)
-- A trigger is code the database runs by itself when a row is inserted / updated / deleted.
-- These keep room availability correct no matter who changes the data (the app, Workbench, a script),
-- and write an audit trail.
--
-- Rule of thumb used here:  room.availability is DERIVED from the stay table.
--   stay inserted as 'Checked In'  -> room becomes Occupied
--   stay set to 'Checked Out'      -> room becomes Available (and Dirty)
--   guest moved to another room    -> old room Available, new room Occupied
--   anyone edits availability by hand to a value that disagrees with the stays -> rejected
--
-- Run this file in Workbench as-is (it uses DELIMITER $$).

USE hotel_mgmt;

DELIMITER $$

-- ---------- STAY ----------

DROP TRIGGER IF EXISTS trg_stay_bi$$
CREATE TRIGGER trg_stay_bi BEFORE INSERT ON stay
FOR EACH ROW
BEGIN
    DECLARE v_avail VARCHAR(30) DEFAULT NULL;
    IF NEW.status = 'Checked In' THEN
        SELECT availability INTO v_avail FROM room WHERE room_number = NEW.room_number;
        IF v_avail IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Room does not exist.';
        ELSEIF v_avail <> 'Available' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Room is not available.';
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_stay_ai$$
CREATE TRIGGER trg_stay_ai AFTER INSERT ON stay
FOR EACH ROW
BEGIN
    IF NEW.status = 'Checked In' THEN
        UPDATE room SET availability = 'Occupied' WHERE room_number = NEW.room_number;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_stay_bu$$
CREATE TRIGGER trg_stay_bu BEFORE UPDATE ON stay
FOR EACH ROW
BEGIN
    DECLARE v_avail VARCHAR(30) DEFAULT NULL;
    IF OLD.status = 'Checked Out' AND NEW.status = 'Checked In' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A checked-out stay cannot be re-opened.';
    END IF;
    IF NEW.status = 'Checked Out' AND NEW.check_out IS NULL THEN
        SET NEW.check_out = CURDATE();
    END IF;
    IF OLD.status = 'Checked In' AND NEW.status = 'Checked In' AND NEW.room_number <> OLD.room_number THEN
        SELECT availability INTO v_avail FROM room WHERE room_number = NEW.room_number;
        IF v_avail IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Room does not exist.';
        ELSEIF v_avail <> 'Available' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Room is not available.';
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_stay_au$$
CREATE TRIGGER trg_stay_au AFTER UPDATE ON stay
FOR EACH ROW
BEGIN
    IF OLD.status = 'Checked In' AND NEW.status = 'Checked Out' THEN
        UPDATE room SET availability = 'Available', cleaning_status = 'Dirty'
        WHERE room_number = OLD.room_number;
    ELSEIF NEW.status = 'Checked In' AND NEW.room_number <> OLD.room_number THEN
        UPDATE room SET availability = 'Available', cleaning_status = 'Dirty'
        WHERE room_number = OLD.room_number;
        UPDATE room SET availability = 'Occupied'
        WHERE room_number = NEW.room_number;
    END IF;
END$$

-- ---------- ROOM_SERVICE ----------

-- Orders may only be added to a stay that is still active.
-- The migration script sets @hotel_migrating = 1 so historical orders of checked-out guests can be copied in.
DROP TRIGGER IF EXISTS trg_room_service_bi$$
CREATE TRIGGER trg_room_service_bi BEFORE INSERT ON room_service
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20) DEFAULT NULL;
    SELECT status INTO v_status FROM stay WHERE stay_id = NEW.stay_id;
    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stay not found.';
    ELSEIF v_status <> 'Checked In' AND @hotel_migrating IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This guest has already checked out.';
    END IF;
END$$

-- ---------- ROOM ----------

-- Availability may only be changed to what the stays say it must be.
DROP TRIGGER IF EXISTS trg_room_bu$$
CREATE TRIGGER trg_room_bu BEFORE UPDATE ON room
FOR EACH ROW
BEGIN
    DECLARE v_active INT DEFAULT 0;
    IF NEW.availability <> OLD.availability THEN
        SELECT COUNT(*) INTO v_active FROM stay
        WHERE room_number = NEW.room_number AND status = 'Checked In';
        IF NEW.availability = 'Available' AND v_active > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Room has a guest checked in. Check the guest out first.';
        ELSEIF NEW.availability = 'Occupied' AND v_active = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Room becomes Occupied automatically when a guest checks in.';
        END IF;
    END IF;
END$$

-- Audit trail for the room master data (price, bed type, cleaning). Availability is derived, so it is not logged.
DROP TRIGGER IF EXISTS trg_room_au$$
CREATE TRIGGER trg_room_au AFTER UPDATE ON room
FOR EACH ROW
BEGIN
    IF NEW.price <> OLD.price OR NEW.bed_type <> OLD.bed_type OR NEW.cleaning_status <> OLD.cleaning_status THEN
        INSERT INTO audit_log (table_name, action, row_key, old_value, new_value, changed_by)
        VALUES ('room', 'UPDATE', NEW.room_number,
                JSON_OBJECT('price', OLD.price, 'bed_type', OLD.bed_type, 'cleaning_status', OLD.cleaning_status),
                JSON_OBJECT('price', NEW.price, 'bed_type', NEW.bed_type, 'cleaning_status', NEW.cleaning_status),
                CURRENT_USER());
    END IF;
END$$

-- ---------- EMPLOYEE / CUSTOMER deletes ----------
-- (Foreign-key cascades do not fire triggers, so the delete procedures delete the subtype row first.)

DROP TRIGGER IF EXISTS trg_employee_ad$$
CREATE TRIGGER trg_employee_ad AFTER DELETE ON employee
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, row_key, old_value, new_value, changed_by)
    VALUES ('employee', 'DELETE', OLD.person_id,
            JSON_OBJECT('name', (SELECT name FROM person WHERE person_id = OLD.person_id),
                        'dept_id', OLD.dept_id, 'salary', OLD.salary),
            NULL, CURRENT_USER());
END$$

DROP TRIGGER IF EXISTS trg_customer_ad$$
CREATE TRIGGER trg_customer_ad AFTER DELETE ON customer
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, row_key, old_value, new_value, changed_by)
    VALUES ('customer', 'DELETE', OLD.person_id,
            JSON_OBJECT('name', (SELECT name FROM person WHERE person_id = OLD.person_id)),
            NULL, CURRENT_USER());
END$$

DELIMITER ;
