# Normalization: from the old schema to the new one

Normal forms in one line each (all tables here have a single-column or composite primary key):

- **1NF**: every column holds one atomic value, no repeating groups.
- **2NF**: 1NF + no column depends on only *part* of a composite key.
- **3NF**: 2NF + no column depends on another non-key column (no *transitive* dependency).
- **BCNF**: for every functional dependency `X -> Y`, `X` is a candidate key. (Stricter than 3NF.)

`A -> B` reads "A determines B".

## 1. What was wrong with the old schema (`hotel`, created by `hotel_db.java`)

| Old table | Problem | Anomaly it causes |
|---|---|---|
| `customer(id, name, phone, email, room_number, check_in, check_out, status)` | Two entities in one row: the **guest** (name, phone, email) and the **stay** (room, dates, status). A returning guest is a brand-new row, so their details are repeated; a second stay cannot be recorded without a second customer. `room_number` has no foreign key. | Update anomaly (change a phone number in several rows), no stay history, orphan room numbers. |
| `add_room(room_number, availability, price, cleaning_status, bed_type)` | `availability` is **derived** from `customer.status` but also stored, so it can disagree with it. | A room shown Available while a guest is checked in (double booking). |
| `employee(id, ..., job, ...)` | `job` is free text repeated on every row; "department" is not an entity. | Typos create new "departments"; deleting the last Chef deletes the fact that a Chef job exists; renaming a job means updating many rows. |
| `room_service(customer_id, cost, ...)` | Linked to the customer, not to the stay; price columns are `DOUBLE`. | A repeat guest's old and new bills are mixed; rounding errors. |
| `user(username, password)` | Plain-text password, no role. | Security, not normalization, but fixed in the same redesign. |

The old tables were technically in 3NF *per table*, but the **design** hid entities (stay, department) and kept a derived value, which is what normalization is meant to remove.

## 2. The new schema and its functional dependencies

| Table | Key(s) | Functional dependencies | Highest normal form |
|---|---|---|---|
| `department` | `dept_id`; candidate key `name` | `dept_id -> name`, `name -> dept_id` | BCNF |
| `person` | `person_id` | `person_id -> name, phone, email, gender, age` | BCNF |
| `customer` | `person_id` | `person_id -> registered_on` | BCNF |
| `employee` | `person_id`; candidate key `aadhaar` | `person_id -> dept_id, salary, aadhaar, hire_date`; `aadhaar -> person_id` (aadhaar is a candidate key, so BCNF still holds) | BCNF |
| `driver` | `person_id` | `person_id -> car_model, availability, location` | BCNF |
| `staff_user` | `user_id`; candidate key `username` | `user_id -> username, password_hash, role`; `username -> user_id` | BCNF |
| `room` | `room_number` | `room_number -> bed_type, price, cleaning_status, availability` | BCNF (see note 1) |
| `stay` | `stay_id` | `stay_id -> customer_id, room_number, check_in, expected_check_out, check_out, nightly_rate, status` | BCNF (see note 2) |
| `room_service` | `order_id` | `order_id -> stay_id, service_name, cost, order_date` | BCNF |
| `invoice` | `invoice_id`; candidate key `stay_id` | `invoice_id -> stay_id, issued_on, nights, room_total, service_total, grand_total`; `stay_id -> invoice_id` | BCNF (see note 3) |
| `invoice_item` | `(invoice_id, line_no)` | `(invoice_id, line_no) -> description, amount` | BCNF (full key needed, so 2NF holds) |
| `audit_log` | `log_id` | `log_id -> all other columns` | BCNF |

### What each step fixed

1. **1NF**: all columns atomic (one phone, one e-mail, one date per column). No repeating groups.
2. **2NF**: the only composite key is `invoice_item(invoice_id, line_no)`. `description` and `amount` describe *that line*, so they depend on the whole key.
3. **3NF**:
   - `employee.job` (text) -> `department` table + `employee.dept_id`. The department name now lives in exactly one row.
   - Guest data and stay data separated (`customer`/`person` vs `stay`), so a guest's contact details are stored once.
   - Shared columns (name, phone, email, gender, age) moved from three tables into `person` (generalization), so they are stored once and validated once.
4. **BCNF**: in every table the left side of every dependency is a candidate key (checked in the table above). The one place that needs a sentence is `employee.aadhaar -> person_id`: `aadhaar` is declared `UNIQUE`, i.e. it *is* a candidate key, so the dependency is allowed.

### Deliberate exceptions (documented, not accidental)

1. **`room.availability` is derived** from the stays. It is kept because "show me free rooms" is the most common query and a stored column is simple and fast. The risk the old schema had (the two copies disagreeing) is removed by *enforcement*: triggers set it, `trg_room_bu` rejects any manual change that contradicts the stays, and the unique key `uq_one_active_stay_per_room` makes two active stays in one room impossible.
2. **`stay.nightly_rate` copies `room.price`** at check-in. This is not redundancy: it is a historical fact about *that stay* ("what was this guest charged"), which must not change when the room price later changes.
3. **`invoice.nights / room_total / service_total` are a snapshot** of values derivable from `stay` and `room_service`. An invoice is a legal-style document and must not change after it is issued, so it stores the numbers. `grand_total` is a generated column so it can never disagree with its two parts.
4. **`person.age`** is a stored age (as the forms collect it), which strictly speaking should be derived from a date of birth. Kept to avoid changing the forms; a `date_of_birth` column would be the fully normalized choice.
