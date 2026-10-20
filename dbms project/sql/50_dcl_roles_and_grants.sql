-- 50_dcl_roles_and_grants.sql  (DCL: CREATE USER / CREATE ROLE / GRANT / REVOKE)
-- Who may do what. Principle of least privilege:
--   * nobody except the DBA (root) gets direct INSERT/UPDATE/DELETE on the tables;
--   * everyone works through VIEWS (read) and PROCEDURES (write). Views and procedures run with their
--     creator's rights (SQL SECURITY DEFINER), so a user needs no access to the tables underneath.
--
-- Roles
--   reception_role : front-desk work (check-in/out, room service, billing, read-only lists).
--   owner_role     : everything reception can do (inherits it) + rooms, employees, drivers, revenue, salaries.
-- Accounts (CHANGE THESE PASSWORDS before real use; they are examples)
--   hotel_app       : the account the Java app connects with (config.properties). Has owner_role because ONE
--                     app connection serves both screens; the app itself hides the Owner panel from receptionists.
--   hotel_reception : a login for a person who should only do front-desk work (e.g. in Workbench).
--   hotel_owner     : a login for the owner in Workbench.
--
-- Run as root (needs CREATE USER / GRANT privileges) AFTER 40_procedures.sql.

USE hotel_mgmt;

CREATE ROLE IF NOT EXISTS 'reception_role', 'owner_role';

-- ---------- reception_role: read ----------
GRANT SELECT ON hotel_mgmt.v_room_info          TO 'reception_role';
GRANT SELECT ON hotel_mgmt.v_available_rooms    TO 'reception_role';
GRANT SELECT ON hotel_mgmt.v_customer_info      TO 'reception_role';
GRANT SELECT ON hotel_mgmt.v_current_guests     TO 'reception_role';
GRANT SELECT ON hotel_mgmt.v_stay_bill          TO 'reception_role';
GRANT SELECT ON hotel_mgmt.v_employee_directory TO 'reception_role';   -- no salary / Aadhaar
GRANT SELECT ON hotel_mgmt.v_driver_info        TO 'reception_role';

-- ---------- reception_role: write (procedures only) ----------
GRANT EXECUTE ON PROCEDURE hotel_mgmt.sp_login            TO 'reception_role';
GRANT EXECUTE ON PROCEDURE hotel_mgmt.sp_check_in         TO 'reception_role';
GRANT EXECUTE ON PROCEDURE hotel_mgmt.sp_check_out        TO 'reception_role';
GRANT EXECUTE ON PROCEDURE hotel_mgmt.sp_change_room      TO 'reception_role';
GRANT EXECUTE ON PROCEDURE hotel_mgmt.sp_update_customer  TO 'reception_role';
GRANT EXECUTE ON PROCEDURE hotel_mgmt.sp_add_room_service TO 'reception_role';
GRANT EXECUTE ON PROCEDURE hotel_mgmt.sp_generate_invoice TO 'reception_role';

-- ---------- owner_role = reception_role + owner-only rights ----------
GRANT 'reception_role' TO 'owner_role';
GRANT SELECT  ON hotel_mgmt.v_employee_full   TO 'owner_role';          -- salary + Aadhaar
GRANT SELECT  ON hotel_mgmt.v_revenue_summary TO 'owner_role';
GRANT SELECT  ON hotel_mgmt.department        TO 'owner_role';          -- fills the department dropdown
GRANT EXECUTE ON PROCEDURE hotel_mgmt.sp_add_room        TO 'owner_role';
GRANT EXECUTE ON PROCEDURE hotel_mgmt.sp_update_room     TO 'owner_role';
GRANT EXECUTE ON PROCEDURE hotel_mgmt.sp_add_employee    TO 'owner_role';
GRANT EXECUTE ON PROCEDURE hotel_mgmt.sp_delete_employee TO 'owner_role';
GRANT EXECUTE ON PROCEDURE hotel_mgmt.sp_add_driver      TO 'owner_role';
GRANT EXECUTE ON PROCEDURE hotel_mgmt.sp_update_driver   TO 'owner_role';
GRANT EXECUTE ON PROCEDURE hotel_mgmt.sp_delete_driver   TO 'owner_role';
GRANT EXECUTE ON PROCEDURE hotel_mgmt.sp_revenue_report  TO 'owner_role';

-- ---------- accounts ----------
CREATE USER IF NOT EXISTS 'hotel_app'@'localhost'       IDENTIFIED BY 'HotelApp#2026';
CREATE USER IF NOT EXISTS 'hotel_reception'@'localhost' IDENTIFIED BY 'Reception#2026';
CREATE USER IF NOT EXISTS 'hotel_owner'@'localhost'     IDENTIFIED BY 'Owner#2026';

GRANT 'owner_role'     TO 'hotel_app'@'localhost';
GRANT 'reception_role' TO 'hotel_reception'@'localhost';
GRANT 'owner_role'     TO 'hotel_owner'@'localhost';

-- Roles must be switched on at login, otherwise the account has no privileges until SET ROLE is run.
SET DEFAULT ROLE ALL TO 'hotel_app'@'localhost', 'hotel_reception'@'localhost', 'hotel_owner'@'localhost';

-- ---------- REVOKE demo ----------
-- Grant a table right, then take it away again.
GRANT  SELECT ON hotel_mgmt.audit_log TO 'reception_role';
REVOKE SELECT ON hotel_mgmt.audit_log FROM 'reception_role';

-- ---------- inspect ----------
SHOW GRANTS FOR 'hotel_reception'@'localhost' USING 'reception_role';
SHOW GRANTS FOR 'hotel_app'@'localhost'       USING 'owner_role';
