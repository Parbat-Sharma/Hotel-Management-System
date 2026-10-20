-- 00_run_all.sql  Builds the whole hotel_mgmt database in one go from the MYSQL COMMAND LINE:
--
--     cd "dbms project/sql"
--     mysql -u root -p < 00_run_all.sql
--
-- (SOURCE is a mysql command-line feature. MySQL Workbench's SQL editor does NOT support it:
--  in Workbench open and run the numbered files one by one, in order. See README.md.)
--
-- Includes: schema (01-13), views (20), triggers (30), procedures (40), users/roles (50), departments + logins (60).
-- Not included on purpose: 61 (optional sample data), 70 (demo), 80 (example queries), 90 (migration).

SOURCE 01_database.sql
SOURCE 02_department.sql
SOURCE 03_person.sql
SOURCE 04_customer.sql
SOURCE 05_employee.sql
SOURCE 06_driver.sql
SOURCE 07_staff_user.sql
SOURCE 08_room.sql
SOURCE 09_stay.sql
SOURCE 10_room_service.sql
SOURCE 11_invoice.sql
SOURCE 12_audit_log.sql
SOURCE 13_indexes_and_alter.sql
SOURCE 20_views.sql
SOURCE 30_triggers.sql
SOURCE 40_procedures.sql
SOURCE 50_dcl_roles_and_grants.sql
SOURCE 60_seed_essentials.sql
