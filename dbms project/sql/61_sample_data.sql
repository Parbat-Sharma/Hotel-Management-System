-- 61_sample_data.sql  (DML: INSERT / UPDATE / DELETE / SELECT)
-- OPTIONAL demo data so every screen has something to show. Do NOT run this on a database you migrated real
-- data into. Run it ONCE, after 60_seed_essentials.sql (it fails with "already exists" if repeated).
-- It goes through the stored procedures on purpose, which also exercises triggers and constraints.

USE hotel_mgmt;

-- ---------- INSERT ----------
CALL sp_add_room('101', 'Single Bed', 1500.00, 'Cleaned');
CALL sp_add_room('102', 'Single Bed', 1500.00, 'Cleaned');
CALL sp_add_room('103', 'Double Bed', 2500.00, 'Dirty');
CALL sp_add_room('201', 'Double Bed', 3200.00, 'Cleaned');
CALL sp_add_room('202', 'Double Bed', 3200.00, 'Cleaned');

CALL sp_add_employee('Anita Sharma', 29, 'Female', 'Front Desk',   28000.00, '9800000001', '123456789012', 'anita@hotel.example');
CALL sp_add_employee('Rohan Thapa',  41, 'Male',   'Management',   65000.00, '9800000002', '123456789013', 'rohan@hotel.example');
CALL sp_add_employee('Maya Gurung',  35, 'Female', 'Housekeeping', 22000.00, '9800000003', '123456789014', 'maya@hotel.example');

CALL sp_add_driver('Bikash Rai',   38, 'Male', 'Toyota Innova', 'Available', 'Airport');
CALL sp_add_driver('Suresh Karki', 45, 'Male', 'Hyundai i20',   'On Trip',   'City Centre');

-- A guest checks into room 101 and orders room service.
CALL sp_check_in('Priya Singh', '9811111111', 'priya@example.com', '101', DATE_ADD(CURDATE(), INTERVAL 2 DAY));
SET @guest = (SELECT person_id FROM person WHERE name = 'Priya Singh');
CALL sp_add_room_service(@guest, 'Breakfast', 450.00);
CALL sp_add_room_service(@guest, 'Laundry',   300.00);

-- ---------- UPDATE ----------
-- Raise the price of room 103 (the audit trigger records old and new values).
UPDATE room SET price = 2700.00 WHERE room_number = '103';
-- Mark a driver as off duty.
UPDATE driver SET availability = 'Off Duty'
WHERE person_id = (SELECT person_id FROM person WHERE name = 'Suresh Karki');

-- ---------- SELECT ----------
SELECT * FROM v_available_rooms;
SELECT * FROM v_current_guests;
SELECT * FROM v_stay_bill;
SELECT * FROM audit_log;

-- ---------- DELETE ----------
-- Remove the off-duty driver through the procedure (the driver row goes with the person row).
SET @driver = (SELECT person_id FROM person WHERE name = 'Suresh Karki');
CALL sp_delete_driver(@driver);
