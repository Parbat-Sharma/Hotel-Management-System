-- 80_queries.sql  (DML: SELECT examples)
-- Read-only example queries over the hotel_mgmt schema: joins, aggregates, subqueries, set operations,
-- window functions, views and stored procedures. Safe to run any time (after some data exists).

USE hotel_mgmt;

-- 1. INNER JOIN across the generalization: who is a customer, with contact details.
SELECT c.person_id AS customer_id, p.name, p.phone, p.email, c.registered_on
FROM customer c
JOIN person p ON p.person_id = c.person_id
ORDER BY p.name;

-- 2. LEFT JOIN: every room with its current guest (NULL when empty).
SELECT r.room_number, r.bed_type, r.availability, p.name AS current_guest
FROM room r
LEFT JOIN stay s   ON s.room_number = r.room_number AND s.status = 'Checked In'
LEFT JOIN person p ON p.person_id = s.customer_id
ORDER BY r.room_number;

-- 3. GROUP BY + HAVING: departments with more than one employee, and their payroll.
SELECT d.name AS department, COUNT(*) AS employees, SUM(e.salary) AS total_salary, AVG(e.salary) AS avg_salary
FROM employee e
JOIN department d ON d.dept_id = e.dept_id
GROUP BY d.dept_id, d.name
HAVING COUNT(*) > 1;

-- 4. All departments including empty ones (LEFT JOIN + COUNT of the right side).
SELECT d.name AS department, COUNT(e.person_id) AS employees
FROM department d
LEFT JOIN employee e ON e.dept_id = d.dept_id
GROUP BY d.dept_id, d.name
ORDER BY employees DESC, d.name;

-- 5. Subquery: rooms priced above the average room price.
SELECT room_number, price
FROM room
WHERE price > (SELECT AVG(price) FROM room)
ORDER BY price DESC;

-- 6. EXISTS: guests who have ordered room service at least once.
SELECT p.name
FROM customer c
JOIN person p ON p.person_id = c.person_id
WHERE EXISTS (SELECT 1
              FROM stay s JOIN room_service rs ON rs.stay_id = s.stay_id
              WHERE s.customer_id = c.person_id);

-- 7. NOT EXISTS: rooms that have never been booked.
SELECT r.room_number
FROM room r
WHERE NOT EXISTS (SELECT 1 FROM stay s WHERE s.room_number = r.room_number);

-- 8. Revenue per room (bill view + GROUP BY).
SELECT room_number, COUNT(*) AS stays, SUM(room_total) AS room_revenue, SUM(service_total) AS service_revenue
FROM v_stay_bill
GROUP BY room_number
ORDER BY room_revenue DESC;

-- 9. Window function: rank guests by what they have been billed.
SELECT guest_name, room_number, grand_total,
       RANK() OVER (ORDER BY grand_total DESC) AS spend_rank
FROM v_stay_bill;

-- 10. UNION: one contact list of all employees and drivers.
SELECT p.name, 'Employee' AS kind, p.phone FROM employee e JOIN person p ON p.person_id = e.person_id
UNION
SELECT p.name, 'Driver'   AS kind, p.phone FROM driver dr JOIN person p ON p.person_id = dr.person_id
ORDER BY kind, name;

-- 11. Weak entity: the lines of every invoice, with the owning invoice.
SELECT i.invoice_id, i.issued_on, ii.line_no, ii.description, ii.amount
FROM invoice i
JOIN invoice_item ii ON ii.invoice_id = i.invoice_id
ORDER BY i.invoice_id, ii.line_no;

-- 12. Audit trail, newest first.
SELECT changed_at, table_name, action, row_key, changed_by, old_value, new_value
FROM audit_log
ORDER BY log_id DESC;

-- 13. The views the app uses.
SELECT * FROM v_available_rooms;
SELECT * FROM v_current_guests;
SELECT * FROM v_revenue_summary;
SELECT * FROM v_employee_directory;       -- no salary / Aadhaar
SELECT * FROM v_driver_info;

-- 14. Stored procedures: revenue for this month, and all time.
CALL sp_revenue_report(DATE_FORMAT(CURDATE(), '%Y-%m-01'), LAST_DAY(CURDATE()));
CALL sp_revenue_report(NULL, NULL);
