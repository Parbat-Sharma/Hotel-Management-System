-- 40_procedures.sql  (STORED PROCEDURES + 1 FUNCTION, with TCL: START TRANSACTION / COMMIT / ROLLBACK)
-- Each procedure is one business operation that must succeed or fail AS A WHOLE:
--   * validates its inputs and raises a readable error (SIGNAL) if something is wrong,
--   * runs all its statements inside one transaction,
--   * on any error the EXIT HANDLER does ROLLBACK, so there are never half-saved rows,
--   * rows that decide the outcome (the room) are locked with SELECT ... FOR UPDATE, so two receptionists
--     can never book the same room at the same time.
-- The Java app calls these (CALL sp_...) instead of building SQL itself, which also removes SQL-injection risk.
--
-- Run this file in Workbench as-is (it uses DELIMITER $$).

USE hotel_mgmt;

DELIMITER $$

-- ---------- helper function ----------

DROP FUNCTION IF EXISTS fn_active_stay$$
CREATE FUNCTION fn_active_stay(p_customer_id INT) RETURNS INT
    READS SQL DATA
BEGIN
    DECLARE v_stay INT DEFAULT NULL;
    SELECT stay_id INTO v_stay FROM stay
    WHERE customer_id = p_customer_id AND status = 'Checked In'
    ORDER BY stay_id DESC LIMIT 1;
    RETURN v_stay;
END$$

-- ---------- login ----------

DROP PROCEDURE IF EXISTS sp_login$$
CREATE PROCEDURE sp_login(IN p_username VARCHAR(100), IN p_password VARCHAR(100))
BEGIN
    -- Returns one row (the role) when the credentials are right, no rows otherwise.
    SELECT role FROM staff_user
    WHERE username = p_username AND password_hash = SHA2(p_password, 256);
END$$

-- ---------- reception ----------

DROP PROCEDURE IF EXISTS sp_check_in$$
CREATE PROCEDURE sp_check_in(IN p_name VARCHAR(100), IN p_phone VARCHAR(20), IN p_email VARCHAR(100),
                             IN p_room VARCHAR(20), IN p_expected_out DATE)
BEGIN
    DECLARE v_avail VARCHAR(30) DEFAULT NULL;
    DECLARE v_price DECIMAL(10,2) DEFAULT NULL;
    DECLARE v_person INT;
    DECLARE v_stay INT;
    DECLARE v_msg VARCHAR(128);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_name IS NULL OR TRIM(p_name) = '' OR p_room IS NULL OR TRIM(p_room) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Guest name and room number are required.';
    END IF;
    IF p_expected_out IS NOT NULL AND p_expected_out < CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Check-out date cannot be in the past.';
    END IF;

    START TRANSACTION;

    -- Lock the room row: a second check-in for this room waits here until we commit or roll back.
    SELECT availability, price INTO v_avail, v_price
    FROM room WHERE room_number = TRIM(p_room) FOR UPDATE;

    IF v_avail IS NULL THEN
        SET v_msg = CONCAT('Room ', TRIM(p_room), ' does not exist. Ask the owner to add it first.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    IF v_avail <> 'Available' THEN
        SET v_msg = CONCAT('Room ', TRIM(p_room), ' is not available (', v_avail, ').');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    INSERT INTO person (name, phone, email) VALUES (TRIM(p_name), TRIM(p_phone), TRIM(p_email));
    SET v_person = LAST_INSERT_ID();
    INSERT INTO customer (person_id) VALUES (v_person);
    -- nightly_rate is frozen here. The trigger trg_stay_ai marks the room Occupied.
    INSERT INTO stay (customer_id, room_number, check_in, expected_check_out, nightly_rate)
    VALUES (v_person, TRIM(p_room), CURDATE(), p_expected_out, v_price);
    SET v_stay = LAST_INSERT_ID();

    COMMIT;
    SELECT v_person AS customer_id, v_stay AS stay_id;
END$$

DROP PROCEDURE IF EXISTS sp_check_out$$
CREATE PROCEDURE sp_check_out(IN p_customer_id INT)
BEGIN
    DECLARE v_stay INT DEFAULT NULL;
    DECLARE v_room VARCHAR(20) DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    SELECT stay_id, room_number INTO v_stay, v_room
    FROM stay WHERE customer_id = p_customer_id AND status = 'Checked In'
    ORDER BY stay_id DESC LIMIT 1 FOR UPDATE;

    IF v_stay IS NULL THEN
        IF EXISTS (SELECT 1 FROM customer WHERE person_id = p_customer_id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This guest is not currently checked in.';
        ELSE
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Customer ID was not found.';
        END IF;
    END IF;

    -- trg_stay_au frees the room and marks it Dirty.
    UPDATE stay SET status = 'Checked Out', check_out = CURDATE() WHERE stay_id = v_stay;
    COMMIT;
    SELECT v_room AS room_number;
END$$

DROP PROCEDURE IF EXISTS sp_change_room$$
CREATE PROCEDURE sp_change_room(IN p_customer_id INT, IN p_new_room VARCHAR(20))
BEGIN
    DECLARE v_stay INT DEFAULT NULL;
    DECLARE v_old VARCHAR(20) DEFAULT NULL;
    DECLARE v_avail VARCHAR(30) DEFAULT NULL;
    DECLARE v_price DECIMAL(10,2) DEFAULT NULL;
    DECLARE v_msg VARCHAR(128);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_new_room IS NULL OR TRIM(p_new_room) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Room number is required.';
    END IF;

    START TRANSACTION;
    SELECT stay_id, room_number INTO v_stay, v_old
    FROM stay WHERE customer_id = p_customer_id AND status = 'Checked In'
    ORDER BY stay_id DESC LIMIT 1 FOR UPDATE;

    IF v_stay IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This guest is not currently checked in.';
    END IF;

    IF v_old <> TRIM(p_new_room) THEN
        SELECT availability, price INTO v_avail, v_price
        FROM room WHERE room_number = TRIM(p_new_room) FOR UPDATE;
        IF v_avail IS NULL THEN
            SET v_msg = CONCAT('Room ', TRIM(p_new_room), ' does not exist.');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;
        IF v_avail <> 'Available' THEN
            SET v_msg = CONCAT('Room ', TRIM(p_new_room), ' is not available (', v_avail, ').');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;
        -- ponytail: the whole stay is billed at the NEW room's rate (no split-rate billing). Add a stay_room
        -- history table if per-room billing is ever needed.
        UPDATE stay SET room_number = TRIM(p_new_room), nightly_rate = v_price WHERE stay_id = v_stay;
    END IF;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS sp_update_customer$$
CREATE PROCEDURE sp_update_customer(IN p_customer_id INT, IN p_name VARCHAR(100),
                                    IN p_phone VARCHAR(20), IN p_email VARCHAR(100))
BEGIN
    IF p_name IS NULL OR TRIM(p_name) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Guest name is required.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM customer WHERE person_id = p_customer_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Customer ID was not found.';
    END IF;
    UPDATE person SET name = TRIM(p_name), phone = TRIM(p_phone), email = TRIM(p_email)
    WHERE person_id = p_customer_id;
END$$

DROP PROCEDURE IF EXISTS sp_add_room_service$$
CREATE PROCEDURE sp_add_room_service(IN p_customer_id INT, IN p_service VARCHAR(255), IN p_cost DECIMAL(10,2))
BEGIN
    DECLARE v_stay INT DEFAULT NULL;
    IF p_service IS NULL OR TRIM(p_service) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Service name is required.';
    END IF;
    IF p_cost IS NULL OR p_cost <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cost must be greater than 0.';
    END IF;
    SET v_stay = fn_active_stay(p_customer_id);
    IF v_stay IS NULL THEN
        IF EXISTS (SELECT 1 FROM customer WHERE person_id = p_customer_id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This guest is not currently checked in.';
        ELSE
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Customer ID was not found.';
        END IF;
    END IF;
    INSERT INTO room_service (stay_id, service_name, cost) VALUES (v_stay, TRIM(p_service), p_cost);
END$$

-- Bills the customer's current stay (or latest stay if checked out) and returns TWO result sets:
--   1) the invoice header   2) the invoice lines.
-- An invoice for a checked-out stay is frozen: calling this again returns the same invoice.
DROP PROCEDURE IF EXISTS sp_generate_invoice$$
CREATE PROCEDURE sp_generate_invoice(IN p_customer_id INT)
BEGIN
    DECLARE v_stay INT DEFAULT NULL;
    DECLARE v_status VARCHAR(20) DEFAULT NULL;
    DECLARE v_inv INT DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT stay_id, status INTO v_stay, v_status
    FROM stay WHERE customer_id = p_customer_id
    ORDER BY (status = 'Checked In') DESC, stay_id DESC LIMIT 1;

    IF v_stay IS NULL THEN
        IF EXISTS (SELECT 1 FROM customer WHERE person_id = p_customer_id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This customer has no stay to bill.';
        ELSE
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Customer not found.';
        END IF;
    END IF;

    START TRANSACTION;
    SELECT invoice_id INTO v_inv FROM invoice WHERE stay_id = v_stay FOR UPDATE;

    IF v_inv IS NULL OR v_status = 'Checked In' THEN
        IF v_inv IS NOT NULL THEN
            DELETE FROM invoice WHERE invoice_id = v_inv;   -- its lines go too (ON DELETE CASCADE)
        END IF;
        INSERT INTO invoice (stay_id, nights, room_total, service_total)
        SELECT stay_id, nights, room_total, service_total FROM v_stay_bill WHERE stay_id = v_stay;
        SET v_inv = LAST_INSERT_ID();

        INSERT INTO invoice_item (invoice_id, line_no, description, amount)
        SELECT v_inv, 1, CONCAT('Room ', room_number, ': ', nights, ' night(s) x ', nightly_rate), room_total
        FROM v_stay_bill WHERE stay_id = v_stay;

        INSERT INTO invoice_item (invoice_id, line_no, description, amount)
        SELECT v_inv, 1 + ROW_NUMBER() OVER (ORDER BY order_id), service_name, cost
        FROM room_service WHERE stay_id = v_stay;
    END IF;
    COMMIT;

    SELECT i.invoice_id, p.name AS guest_name, s.room_number, i.nights,
           i.room_total, i.service_total, i.grand_total, i.issued_on
    FROM invoice i
    JOIN stay s   ON s.stay_id = i.stay_id
    JOIN person p ON p.person_id = s.customer_id
    WHERE i.invoice_id = v_inv;

    SELECT line_no, description, amount FROM invoice_item WHERE invoice_id = v_inv ORDER BY line_no;
END$$

-- ---------- owner: rooms ----------

DROP PROCEDURE IF EXISTS sp_add_room$$
CREATE PROCEDURE sp_add_room(IN p_room VARCHAR(20), IN p_bed VARCHAR(30), IN p_price DECIMAL(10,2),
                             IN p_cleaning VARCHAR(30))
BEGIN
    DECLARE EXIT HANDLER FOR 1062
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This room number already exists.';
    IF p_room IS NULL OR TRIM(p_room) NOT REGEXP '^[0-9]+$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Room Number must contain numbers only.';
    END IF;
    IF p_price IS NULL OR p_price <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Price must be greater than 0.';
    END IF;
    -- New rooms always start Available; the stay triggers manage availability from then on.
    INSERT INTO room (room_number, bed_type, price, cleaning_status, availability)
    VALUES (TRIM(p_room), p_bed, p_price, p_cleaning, 'Available');
END$$

DROP PROCEDURE IF EXISTS sp_update_room$$
CREATE PROCEDURE sp_update_room(IN p_room VARCHAR(20), IN p_bed VARCHAR(30), IN p_price DECIMAL(10,2),
                                IN p_cleaning VARCHAR(30))
BEGIN
    IF p_price IS NULL OR p_price <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Price must be greater than 0.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM room WHERE room_number = p_room) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Room not found.';
    END IF;
    -- Availability is deliberately NOT a parameter: only check-in / check-out change it.
    UPDATE room SET bed_type = p_bed, price = p_price, cleaning_status = p_cleaning
    WHERE room_number = p_room;
END$$

-- ---------- owner: employees ----------

DROP PROCEDURE IF EXISTS sp_add_employee$$
CREATE PROCEDURE sp_add_employee(IN p_name VARCHAR(100), IN p_age INT, IN p_gender VARCHAR(20),
                                 IN p_department VARCHAR(60), IN p_salary DECIMAL(10,2),
                                 IN p_phone VARCHAR(20), IN p_aadhaar VARCHAR(20), IN p_email VARCHAR(100))
BEGIN
    DECLARE v_dept INT DEFAULT NULL;
    DECLARE v_person INT;
    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'An employee with this Aadhaar number already exists.';
    END;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_name IS NULL OR TRIM(p_name) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Name is required.';
    END IF;
    IF p_age IS NULL OR p_age < 18 OR p_age > 70 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Age must be between 18 and 70.';
    END IF;
    IF p_salary IS NULL OR p_salary <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Salary must be greater than 0.';
    END IF;
    IF p_phone IS NULL OR p_phone NOT REGEXP '^[0-9]{10}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Phone number must contain exactly 10 digits.';
    END IF;
    IF p_aadhaar IS NULL OR p_aadhaar NOT REGEXP '^[0-9]{12}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aadhaar must contain exactly 12 digits.';
    END IF;
    SELECT dept_id INTO v_dept FROM department WHERE name = p_department;
    IF v_dept IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Department not found.';
    END IF;

    START TRANSACTION;
    INSERT INTO person (name, phone, email, gender, age)
    VALUES (TRIM(p_name), p_phone, TRIM(p_email), p_gender, p_age);
    SET v_person = LAST_INSERT_ID();
    INSERT INTO employee (person_id, dept_id, salary, aadhaar)
    VALUES (v_person, v_dept, p_salary, p_aadhaar);
    COMMIT;
    SELECT v_person AS employee_id;
END$$

DROP PROCEDURE IF EXISTS sp_delete_employee$$
CREATE PROCEDURE sp_delete_employee(IN p_employee_id INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    IF NOT EXISTS (SELECT 1 FROM employee WHERE person_id = p_employee_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Employee not found.';
    END IF;
    START TRANSACTION;
    DELETE FROM employee WHERE person_id = p_employee_id;   -- fires trg_employee_ad (audit)
    DELETE FROM person   WHERE person_id = p_employee_id;
    COMMIT;
END$$

-- ---------- owner: drivers ----------

DROP PROCEDURE IF EXISTS sp_add_driver$$
CREATE PROCEDURE sp_add_driver(IN p_name VARCHAR(100), IN p_age INT, IN p_gender VARCHAR(20),
                               IN p_car VARCHAR(100), IN p_availability VARCHAR(30), IN p_location VARCHAR(100))
BEGIN
    DECLARE v_person INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    IF p_name IS NULL OR TRIM(p_name) = '' OR p_car IS NULL OR TRIM(p_car) = '' OR p_age IS NULL OR p_age < 18 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Name, age (18+) and car model are required.';
    END IF;
    START TRANSACTION;
    INSERT INTO person (name, gender, age) VALUES (TRIM(p_name), p_gender, p_age);
    SET v_person = LAST_INSERT_ID();
    INSERT INTO driver (person_id, car_model, availability, location)
    VALUES (v_person, TRIM(p_car), p_availability, TRIM(p_location));
    COMMIT;
    SELECT v_person AS driver_id;
END$$

DROP PROCEDURE IF EXISTS sp_update_driver$$
CREATE PROCEDURE sp_update_driver(IN p_driver_id INT, IN p_name VARCHAR(100), IN p_age INT, IN p_gender VARCHAR(20),
                                  IN p_car VARCHAR(100), IN p_availability VARCHAR(30), IN p_location VARCHAR(100))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    IF p_name IS NULL OR TRIM(p_name) = '' OR p_car IS NULL OR TRIM(p_car) = '' OR p_age IS NULL OR p_age < 18 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Name, age (18+) and car model are required.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM driver WHERE person_id = p_driver_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Driver not found.';
    END IF;
    START TRANSACTION;
    UPDATE person SET name = TRIM(p_name), age = p_age, gender = p_gender WHERE person_id = p_driver_id;
    UPDATE driver SET car_model = TRIM(p_car), availability = p_availability, location = TRIM(p_location)
    WHERE person_id = p_driver_id;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS sp_delete_driver$$
CREATE PROCEDURE sp_delete_driver(IN p_driver_id INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM driver WHERE person_id = p_driver_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Driver not found.';
    END IF;
    DELETE FROM person WHERE person_id = p_driver_id;   -- the driver row goes with it (ON DELETE CASCADE)
END$$

-- ---------- owner: report ----------

-- Revenue for stays that began in [p_from, p_to] and orders placed in that range. NULL = no limit on that side.
DROP PROCEDURE IF EXISTS sp_revenue_report$$
CREATE PROCEDURE sp_revenue_report(IN p_from DATE, IN p_to DATE)
BEGIN
    SELECT (SELECT COUNT(*) FROM room) AS total_rooms,
           (SELECT COUNT(*) FROM room WHERE availability = 'Occupied') AS occupied_rooms,
           COALESCE((SELECT SUM(room_total) FROM v_stay_bill
                     WHERE (p_from IS NULL OR check_in >= p_from) AND (p_to IS NULL OR check_in <= p_to)), 0) AS room_revenue,
           COALESCE((SELECT SUM(cost) FROM room_service
                     WHERE (p_from IS NULL OR order_date >= p_from) AND (p_to IS NULL OR order_date <= p_to)), 0) AS service_revenue;
END$$

DELIMITER ;
