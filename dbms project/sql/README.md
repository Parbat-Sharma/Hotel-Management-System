# Hotel database: SQL scripts (MySQL Workbench)

Builds the database `hotel_mgmt` that the Java app now uses. The old `hotel` database is never modified.
Tested on MySQL 8.0 (needs 8.0.16 or newer: CHECK constraints, roles, window functions).

## 1. Build the database in MySQL Workbench

1. Open Workbench and connect as **root** (File > Open SQL Script... opens a file in a new tab).
2. Open and run these files **in this order**. Run a file with the lightning-bolt button (**Ctrl+Shift+Enter**).

| Order | File | What it does |
|---|---|---|
| 1 | `01_database.sql` | creates the database `hotel_mgmt` |
| 2 | `02_department.sql` ... `12_audit_log.sql` | one table per file (see list below) |
| 3 | `13_indexes_and_alter.sql` | extra indexes, an ALTER, and a CREATE/ALTER/DROP demo |
| 4 | `20_views.sql` | 9 views |
| 5 | `30_triggers.sql` | 9 triggers |
| 6 | `40_procedures.sql` | 15 stored procedures + 1 function |
| 7 | `50_dcl_roles_and_grants.sql` | roles, user accounts, GRANT / REVOKE |
| 8 | `60_seed_essentials.sql` | 7 departments + the 2 login accounts |

Command-line alternative (does steps 1 to 8 at once): open a terminal in this folder and run
`mysql -u root -p < 00_run_all.sql`. (`SOURCE` does not work inside Workbench's editor, so there you run the files one by one.)

Tables: `02 department`, `03 person`, `04 customer`, `05 employee`, `06 driver`, `07 staff_user`, `08 room`, `09 stay`, `10 room_service`, `11 invoice` (+ `invoice_item`), `12 audit_log`.

### Optional files
| File | Use it when |
|---|---|
| `61_sample_data.sql` | you want demo rooms/employees/drivers/a guest to click around with. **Not** on a migrated database. Run once. |
| `70_tcl_acid_demo.sql` | showing COMMIT / ROLLBACK / SAVEPOINT / isolation / durability. Uses its own scratch table. |
| `80_queries.sql` | example SELECTs (joins, GROUP BY, subqueries, window function, UNION, views, procedures). |
| `90_migrate_from_old_hotel.sql` | you already have data in the old `hotel` database and want it copied in. Read its header first. |

Docs: `normalization.md` (1NF to BCNF reasoning), `er_diagram.md` (ER diagram, cardinality, participation, weak entity, generalization).

## 2. Connect the Java app

1. Copy `config.properties.example` (in the IntelliJ project folder, next to `IdeaProjects.iml`) to `config.properties`.
2. Put the `hotel_app` password in it. Default from `50_dcl_roles_and_grants.sql` is `HotelApp#2026`. **Change it**:
   `ALTER USER 'hotel_app'@'localhost' IDENTIFIED BY 'your new password';` and use the same one in the file.
3. The MySQL connector jar must be on the project classpath (the IntelliJ library points to `~/Downloads/mysql-connector-j-9.7.0/`; fix that path if the jar is elsewhere).
4. Run `splash`. Log in with **admin / admin123** (Owner) or **reception / reception123** (Receptionist). Change both passwords.
   Only the Owner can open the Owner panel.

The app no longer creates tables itself and no longer contains the database password.

## 3. Which requirement is where

| Requirement | Where |
|---|---|
| DDL (CREATE / ALTER / DROP) | `02` to `12`, `13` |
| DML (INSERT / UPDATE / DELETE / SELECT) | `60`, `61`, `80`, plus every procedure |
| DCL (CREATE USER/ROLE, GRANT, REVOKE) | `50` |
| TCL (START TRANSACTION, COMMIT, ROLLBACK, SAVEPOINT) | `40` (every write procedure), `70` |
| Triggers | `30` (availability kept in step with stays, order rules, audit trail) |
| Normalization (3NF / BCNF) | the table design; reasoning in `normalization.md` |
| Cardinality, participation | `er_diagram.md`; enforced by NOT NULL, UNIQUE, FOREIGN KEY |
| Weak entity | `invoice_item` (key = `invoice_id` + `line_no`) in `11` |
| Generalization / specialization | `person` with `customer`, `employee`, `driver` (`03` to `06`) |
| ACID | InnoDB + procedures with transactions and row locks; shown in `70` |
| Views | `20` |
| Stored procedures | `40` |

## 4. Behaviour worth knowing

- **Double-booking is impossible**: `sp_check_in` locks the room row, and a unique key on the stay table refuses a second active stay in any room.
- **Room availability is automatic.** It changes only through check-in, check-out and room change. Editing it by hand is rejected by a trigger. The Owner's room screens no longer have an availability field.
- **Bills use the rate frozen at check-in**, so changing a room's price later does not change existing stays or issued invoices. After check-out the invoice is frozen.
- **Customer ID** is what the front-desk screens ask for (as before). A guest's check-out, billing and room service act on their *current* stay.
- Rules broken by a user come back as plain messages ("Room 101 is not available (Occupied).").

## 5. Limitations (honest list)

- Passwords are hashed with unsalted SHA-256 in MySQL. Fine for a course project; use bcrypt/argon2 in the app for real use.
- The app uses **one** database account (`hotel_app`, with the owner rights) for both screens, so Receptionist-versus-Owner is enforced by the app. The database-level split exists as the roles `reception_role`/`owner_role` and the accounts `hotel_reception`/`hotel_owner` (log in to Workbench as them to see the restriction).
- The default passwords in these scripts are examples. Change them.
- When a guest changes room, the whole stay is billed at the new room's rate (no split-rate billing).
- Only the SQL side has been run end to end. The Java code compiles, and the SQL it uses was checked by running the same statements against the database, but the app itself has not been clicked through.
