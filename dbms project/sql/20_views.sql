-- 20_views.sql  (VIEWS)
-- A view is a saved query that behaves like a read-only table. The app reads these instead of the base
-- tables, and v_employee_directory deliberately HIDES salary and Aadhaar.
-- Views run with the privileges of their creator (SQL SECURITY DEFINER), so a user granted SELECT on a view
-- does not need any access to the tables underneath (see 50_dcl_roles_and_grants.sql).

USE hotel_mgmt;

-- All rooms (Manage Rooms / Room list).
CREATE OR REPLACE VIEW v_room_info AS
SELECT room_number, bed_type, price, cleaning_status, availability
FROM room;

-- Rooms a guest can be put in right now.
CREATE OR REPLACE VIEW v_available_rooms AS
SELECT room_number, bed_type, price, cleaning_status
FROM room
WHERE availability = 'Available';

-- One row per stay with the guest's details (Customer Info screen).
-- LEFT JOIN: a customer with no stay yet still appears.
CREATE OR REPLACE VIEW v_customer_info AS
SELECT p.person_id AS customer_id,
       p.name, p.phone, p.email,
       s.stay_id, s.room_number, s.check_in,
       s.expected_check_out, s.check_out, s.status
FROM customer c
JOIN person p ON p.person_id = c.person_id
LEFT JOIN stay s ON s.customer_id = c.person_id;

-- Guests who are in the hotel now.
CREATE OR REPLACE VIEW v_current_guests AS
SELECT customer_id, name, phone, email, stay_id, room_number, check_in, expected_check_out
FROM v_customer_info
WHERE status = 'Checked In';

-- The bill for every stay, computed live.
-- nights = days between check-in and check-out (or today if still staying), minimum 1.
-- Uses the nightly_rate frozen at check-in, so changing a room's price never rewrites old stays.
CREATE OR REPLACE VIEW v_stay_bill AS
SELECT t.*, t.room_total + t.service_total AS grand_total
FROM (
    SELECT s.stay_id, s.customer_id, p.name AS guest_name, s.room_number, s.status,
           s.check_in, s.check_out, s.nightly_rate,
           GREATEST(DATEDIFF(COALESCE(s.check_out, CURDATE()), s.check_in), 1) AS nights,
           s.nightly_rate * GREATEST(DATEDIFF(COALESCE(s.check_out, CURDATE()), s.check_in), 1) AS room_total,
           COALESCE((SELECT SUM(rs.cost) FROM room_service rs WHERE rs.stay_id = s.stay_id), 0) AS service_total
    FROM stay s
    JOIN person p ON p.person_id = s.customer_id
) t;

-- One-row hotel summary for the Owner's revenue report.
CREATE OR REPLACE VIEW v_revenue_summary AS
SELECT t.*,
       t.room_revenue + t.service_revenue AS gross_revenue,
       ROUND(100 * t.occupied_rooms / NULLIF(t.total_rooms, 0), 2) AS occupancy_pct
FROM (
    SELECT (SELECT COUNT(*) FROM room) AS total_rooms,
           (SELECT COUNT(*) FROM room WHERE availability = 'Occupied') AS occupied_rooms,
           COALESCE((SELECT SUM(room_total) FROM v_stay_bill), 0) AS room_revenue,
           COALESCE((SELECT SUM(cost) FROM room_service), 0) AS service_revenue
) t;

-- Staff list for the front desk: NO salary, NO Aadhaar.
CREATE OR REPLACE VIEW v_employee_directory AS
SELECT e.person_id AS employee_id, p.name, d.name AS department, p.phone, p.email
FROM employee e
JOIN person p     ON p.person_id = e.person_id
JOIN department d ON d.dept_id   = e.dept_id;

-- Full employee record for the Owner.
CREATE OR REPLACE VIEW v_employee_full AS
SELECT e.person_id AS employee_id, p.name, p.age, p.gender, d.name AS department,
       e.salary, p.phone, e.aadhaar, p.email, e.hire_date
FROM employee e
JOIN person p     ON p.person_id = e.person_id
JOIN department d ON d.dept_id   = e.dept_id;

-- Drivers with their status (Pick Up Service screen and Add Driver screen).
CREATE OR REPLACE VIEW v_driver_info AS
SELECT dr.person_id AS driver_id, p.name, p.age, p.gender,
       dr.car_model, dr.availability, dr.location
FROM driver dr
JOIN person p ON p.person_id = dr.person_id;
