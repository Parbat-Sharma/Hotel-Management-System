-- 90_migrate_from_old_hotel.sql
-- Copies the data from the OLD flat database `hotel` (the one the original app created) into the new `hotel_mgmt`.
-- The old database is only READ, never changed, so you can always go back to it.
--
-- BEFORE YOU RUN:
--   1. Run 01 .. 13, 20, 30, 40, 50 and 60 first (empty hotel_mgmt with its objects).
--   2. Do NOT run 61_sample_data.sql on this database.
--   3. Run it ONCE. Running it twice fails on duplicate keys.
--   4. Run the CHECKS below first; each must return no rows. Fix the old data if one does.
--
-- WHAT CHANGES DURING THE COPY (so nothing surprises you):
--   * Customer ids are kept (customer 7 is still customer 7), so existing bills and receipts still match.
--     Each old customer row becomes: 1 person + 1 customer + (if their room exists) 1 stay.
--   * Employee and driver ids are NEW (they now share one id space with customers).
--   * Employee.job text becomes a department (Front Desk Clerk / Receptionist -> Front Desk, Manager -> Management,
--     Accountant -> Accounts, Chef -> Kitchen, Waiter -> Restaurant, others keep their name).
--   * A stay's nightly rate is the room's CURRENT price (the old data never recorded the price at the time).
--   * Old plain-text passwords are hashed. The user named 'admin' becomes Owner, everyone else Receptionist.
--   * An invalid e-mail (no @) is dropped; an employee with no Aadhaar gets a placeholder 'MIG000000007'
--     (edit it later); an employee with no salary gets NULL.
--   * Customers whose room does not exist in the old room table are copied WITHOUT a stay, and their
--     room-service orders are NOT copied (an order must belong to a stay). The verify query at the end shows the gap.

-- ---------- CHECKS (run these first; each should return zero rows) ----------
-- Two guests checked in to the same room:
SELECT room_number, COUNT(*) AS checked_in_guests
FROM hotel.customer WHERE status = 'Checked In' GROUP BY room_number HAVING COUNT(*) > 1;
-- Duplicate Aadhaar numbers:
SELECT aadhaar, COUNT(*) FROM hotel.employee
WHERE aadhaar IS NOT NULL AND TRIM(aadhaar) <> '' GROUP BY aadhaar HAVING COUNT(*) > 1;
-- Informational: customers whose room is missing from the room table (they will get no stay):
SELECT c.id, c.name, c.room_number FROM hotel.customer c
LEFT JOIN hotel.add_room r ON r.room_number = c.room_number WHERE r.room_number IS NULL;

-- ---------- COPY ----------
USE hotel_mgmt;
SET @hotel_migrating = 1;          -- lets trg_room_service_bi accept old orders of checked-out guests
START TRANSACTION;

-- rooms (all start Available; the stay triggers mark them Occupied as active stays are inserted)
INSERT INTO room (room_number, bed_type, price, cleaning_status, availability)
SELECT room_number,
       IF(bed_type IN ('Single Bed', 'Double Bed'), bed_type, 'Single Bed'),
       IF(price > 0, price, 1.00),
       IF(cleaning_status = 'Dirty', 'Dirty', 'Cleaned'),
       'Available'
FROM hotel.add_room;

-- customers (ids kept)
INSERT INTO person (person_id, name, phone, email)
SELECT id, name, phone, IF(email LIKE '%_@_%' OR email = '', email, NULL)
FROM hotel.customer;

INSERT INTO customer (person_id, registered_on)
SELECT id, COALESCE(check_in, CURDATE()) FROM hotel.customer;

-- stays (stay_id = old customer id; old check_out meant "expected" while checked in, "actual" after)
INSERT INTO stay (stay_id, customer_id, room_number, check_in, expected_check_out, check_out, nightly_rate, status)
SELECT c.id, c.id, c.room_number,
       COALESCE(c.check_in, CURDATE()),
       IF(c.status = 'Checked Out', NULL, IF(c.check_out >= c.check_in, c.check_out, NULL)),
       IF(c.status = 'Checked Out', GREATEST(COALESCE(c.check_in, CURDATE()), COALESCE(c.check_out, c.check_in, CURDATE())), NULL),
       r.price,
       IF(c.status = 'Checked Out', 'Checked Out', 'Checked In')
FROM hotel.customer c
JOIN hotel.add_room r ON r.room_number = c.room_number
ORDER BY c.id;

-- room service (belongs to the stay with the same number as the old customer id)
INSERT INTO room_service (stay_id, service_name, cost, order_date)
SELECT rs.customer_id, rs.service_name, rs.cost, COALESCE(rs.order_date, CURDATE())
FROM hotel.room_service rs
JOIN stay s ON s.stay_id = rs.customer_id
WHERE rs.cost > 0 AND rs.service_name IS NOT NULL;

-- departments from the old job text
INSERT IGNORE INTO department (name)
SELECT DISTINCT m.dept FROM (
    SELECT CASE job
               WHEN 'Front Desk Clerk' THEN 'Front Desk'
               WHEN 'Receptionist'     THEN 'Front Desk'
               WHEN 'Manager'          THEN 'Management'
               WHEN 'Accountant'       THEN 'Accounts'
               WHEN 'Chef'             THEN 'Kitchen'
               WHEN 'Waiter'           THEN 'Restaurant'
               ELSE COALESCE(NULLIF(TRIM(job), ''), 'General')
           END AS dept
    FROM hotel.employee
) m;

-- employees (new ids = offset + old id, so the person and employee rows can be matched)
SET @off = (SELECT COALESCE(MAX(person_id), 0) FROM person);
INSERT INTO person (person_id, name, phone, email, gender, age)
SELECT @off + id, name, phone, IF(email LIKE '%_@_%' OR email = '', email, NULL), gender,
       IF(age BETWEEN 0 AND 120, age, NULL)
FROM hotel.employee;

INSERT INTO employee (person_id, dept_id, salary, aadhaar)
SELECT @off + e.id, d.dept_id,
       IF(e.salary > 0, e.salary, NULL),
       COALESCE(NULLIF(TRIM(e.aadhaar), ''), CONCAT('MIG', LPAD(e.id, 9, '0')))
FROM (
    SELECT x.*, CASE x.job
               WHEN 'Front Desk Clerk' THEN 'Front Desk'
               WHEN 'Receptionist'     THEN 'Front Desk'
               WHEN 'Manager'          THEN 'Management'
               WHEN 'Accountant'       THEN 'Accounts'
               WHEN 'Chef'             THEN 'Kitchen'
               WHEN 'Waiter'           THEN 'Restaurant'
               ELSE COALESCE(NULLIF(TRIM(x.job), ''), 'General')
           END AS dept
    FROM hotel.employee x
) e
JOIN department d ON d.name = e.dept;

-- drivers
SET @off = (SELECT COALESCE(MAX(person_id), 0) FROM person);
INSERT INTO person (person_id, name, gender, age)
SELECT @off + id, name, gender, IF(age BETWEEN 0 AND 120, age, NULL)
FROM hotel.driver;

INSERT INTO driver (person_id, car_model, availability, location)
SELECT @off + id, car_model,
       IF(availability IN ('Available', 'On Trip', 'Off Duty'), availability, 'Available'),
       location
FROM hotel.driver;

-- login accounts (existing seeded accounts get the old password)
INSERT INTO staff_user (username, password_hash, role)
SELECT username, SHA2(password, 256), IF(username = 'admin', 'Owner', 'Receptionist')
FROM hotel.`user`
ON DUPLICATE KEY UPDATE password_hash = VALUES(password_hash);

COMMIT;
SET @hotel_migrating = NULL;

-- ---------- VERIFY (each pair of numbers should match, except as explained above) ----------
SELECT 'rooms'      AS what, (SELECT COUNT(*) FROM hotel.add_room)     AS old_count, (SELECT COUNT(*) FROM hotel_mgmt.room)         AS new_count
UNION ALL SELECT 'customers',    (SELECT COUNT(*) FROM hotel.customer),     (SELECT COUNT(*) FROM hotel_mgmt.customer)
UNION ALL SELECT 'employees',    (SELECT COUNT(*) FROM hotel.employee),     (SELECT COUNT(*) FROM hotel_mgmt.employee)
UNION ALL SELECT 'drivers',      (SELECT COUNT(*) FROM hotel.driver),       (SELECT COUNT(*) FROM hotel_mgmt.driver)
UNION ALL SELECT 'room service', (SELECT COUNT(*) FROM hotel.room_service), (SELECT COUNT(*) FROM hotel_mgmt.room_service)
UNION ALL SELECT 'logins',       (SELECT COUNT(*) FROM hotel.`user`),       (SELECT COUNT(*) FROM hotel_mgmt.staff_user);
-- 'customers' differ from stays only for guests whose room was missing; 'logins' may be larger by the seeded 'reception'.
