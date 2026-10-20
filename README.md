# Hotel Management System

A desktop hotel management application written in **Java Swing** with a **MySQL** database. Reception staff check guests in and out, bill stays and log room service; the owner manages rooms, employees and drivers and sees a revenue report.

The database is the main part of this project: it is built from plain SQL scripts and uses views, triggers, stored procedures, transactions, roles and permissions, and a normalized (3NF/BCNF) schema.

## Features

**Reception**
- Check a guest in to an available room
- Update guest details and change a guest's room
- Room service orders
- Billing: itemized invoice, frozen after check-out
- Check out (the room is freed and marked dirty automatically)
- Lists: rooms, customers, drivers (pick-up service), staff directory

**Owner** (login role `Owner`)
- Add and edit rooms, add and delete employees, add / update / delete drivers
- Revenue report with occupancy rate

**Security**
- Two roles, Owner and Receptionist; only the Owner can open the Owner panel
- Passwords stored as hashes, never as plain text
- The app connects with a least-privilege database account that can only run stored procedures and read views
- Database password kept in a git-ignored `config.properties`, not in the source

## Tech

| | |
|---|---|
| Language / UI | Java (Swing). Developed and tested with JDK 26 |
| Database | MySQL 8.0 (8.0.16 or newer needed for CHECK constraints, roles, window functions) |
| Driver | MySQL Connector/J (tested with 26.7.0) |
| Database tool | MySQL Workbench (for running the SQL scripts) |

## Project layout

```
.
├── run.bat                      compile and start the app (Windows)
├── config.properties.example    copy to config.properties and set the DB password
└── dbms project
    ├── src
    │   ├── hotel                the Java source (splash.java starts the app)
    │   └── icon                 images
    └── sql                      the database, as numbered SQL scripts
        ├── README.md            SQL setup details
        ├── er_diagram.md        ER diagram (crow's foot) + cardinality / participation
        ├── chen_er_diagram.md   build sheet for a Chen-notation diagram
        └── normalization.md     normal forms, with functional dependencies per table
```

## Getting started

### 1. Prerequisites
- A JDK installed and on your PATH (`javac -version` works)
- MySQL Server 8.0 running on `localhost:3306`, and MySQL Workbench
- The [MySQL Connector/J](https://dev.mysql.com/downloads/connector/j/) jar (Platform Independent ZIP, unzipped)

### 2. Build the database
In MySQL Workbench, connected as `root`, open and run these files from `dbms project/sql/`, **in this order**:

`01`, `02` to `12`, `13`, `20_views`, `30_triggers`, `40_procedures`, `50_dcl_roles_and_grants`, `60_seed_essentials`

(`61_sample_data.sql` is optional demo data. `70_tcl_acid_demo.sql` and `80_queries.sql` are demos and example queries.) Full details are in [`dbms project/sql/README.md`](dbms%20project/sql/README.md).

### 3. Configure the app
1. Copy `config.properties.example` to `config.properties` (same folder).
2. Set `db.password` to the password of the `hotel_app` MySQL account. The scripts create it with an example password; change it with `ALTER USER 'hotel_app'@'localhost' IDENTIFIED BY '...';` and use the same value in the file.

### 4. Run
Double-click `run.bat`. It expects the connector jar at
`%USERPROFILE%\Downloads\mysql-connector-j-26.7.0\mysql-connector-j-26.7.0\mysql-connector-j-26.7.0.jar`;
edit the `JAR=` line in `run.bat` if yours is elsewhere.

(In IntelliJ instead: open the project folder, add the connector jar under *File > Project Structure > Libraries*, and run `hotel.splash`.)

### 5. Log in
The scripts create two example accounts, **`admin`** (Owner) and **`reception`** (Receptionist); their initial passwords are in `60_seed_essentials.sql`. **Change them before using the app for anything real**:

```sql
USE hotel_mgmt;
UPDATE staff_user SET password_hash = SHA2('your-new-password', 256) WHERE username = 'admin';
```

## Database design in short

| Requirement | Where |
|---|---|
| DDL, DML, DCL, TCL | `sql/01`-`13`, `60`/`61`/`80`, `50`, `40`/`70` |
| Triggers (9) | `30_triggers.sql`: room availability follows the stays, orders only on active stays, audit trail |
| Views (9) | `20_views.sql` |
| Stored procedures (15) | `40_procedures.sql`: every write is one transaction with row locks |
| Normalization (3NF / BCNF) | `normalization.md` |
| Generalization / specialization | `person` with `customer`, `employee`, `driver` |
| Weak entity | `invoice_item` (key = `invoice_id` + `line_no`) |
| M:N resolved | `stay` joins customer and room |

Two guarantees worth knowing: **a room can never be double-booked** (row lock in `sp_check_in`, plus a unique key on active stays), and **old bills never change when a room price changes** (the nightly rate is stored at check-in).

## Known limitations
- Passwords use unsalted SHA-256, fine for a course project but not for production
- The app uses one database account for both screens, so Owner-versus-Receptionist is enforced by the app; database-level roles exist for Workbench logins
- When a guest changes room, the whole stay is billed at the new room's rate
- No automated tests; the SQL demo files and manual use are the checks
- Windows `run.bat` only; on other systems compile with `javac` and run `hotel.splash` with the connector jar on the classpath

## Troubleshooting
| Message | Cause |
|---|---|
| `config.properties not found` | Create it from the example, in the same folder as `run.bat` |
| `Access denied` | `db.password` does not match the `hotel_app` password |
| `Database hotel_mgmt not found` | The SQL scripts have not been run |
| `MySQL driver not found` / jar not found | Fix the jar path (`run.bat` or IntelliJ library) |
| `Cannot reach MySQL on localhost:3306` | Start the MySQL server |
