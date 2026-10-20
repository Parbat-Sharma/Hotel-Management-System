# Chen ER diagram: build sheet for Figma / FigJam

Everything you need to draw the hotel database in **Chen notation**. Work top to bottom: shapes, then entities and attributes, then relationships, then layout.
Tip: **FigJam** (Figma's whiteboard) already has rectangle, diamond, ellipse, triangle and connector tools, so it is faster than Figma Design for this.

## 1. Shape legend (what to draw)

| Concept | Chen shape | Figma how-to |
|---|---|---|
| Strong entity | Rectangle | 160 x 50, 2 px outline, name in CAPITALS |
| Weak entity | **Double** rectangle | Two rectangles, the outer 8 px bigger than the inner |
| Associative entity (relationship that is also an entity) | Rectangle with a diamond inside | Diamond drawn inside the rectangle |
| Attribute | Ellipse | 120 x 40, name in lowercase |
| Key attribute | Ellipse, name **underlined** | Underline the text |
| Partial key (weak entity) | Ellipse, name with **dashed underline** | Dashed underline or an underscore line under the text |
| Derived attribute | **Dashed** ellipse | Set the stroke to dashed |
| Relationship | Diamond | 130 x 80, name in CAPITALS (a verb) |
| Identifying relationship (owner of a weak entity) | **Double** diamond | Two diamonds, outer 8 px bigger |
| Total participation | **Double line** between entity and relationship | Two parallel 1 px lines, or one 4 px line with a thin white line down the middle |
| Partial participation | Single line | 1.5 px line |
| Cardinality | Label `1` or `N` next to the entity end of the line | Text, 14 px |
| Specialization (ISA) | Triangle pointing at the supertype, with a letter inside: `d` = disjoint, `o` = overlapping | Triangle, apex towards PERSON |

Colour suggestion: entities light blue, weak entity light orange, associative entity light green, relationships light yellow, attributes white.

## 2. Entities and their attributes

Underline = primary key. `(derived)` = dashed ellipse. Draw each attribute as an ellipse joined to its entity by a plain line.

| Entity | Attributes |
|---|---|
| **PERSON** | <u>person_id</u>, name, phone, email, gender, age |
| **CUSTOMER** | registered_on  *(key comes from PERSON)* |
| **EMPLOYEE** | salary, aadhaar, hire_date  *(key comes from PERSON; `aadhaar` is a unique candidate key)* |
| **DRIVER** | car_model, availability, location  *(key comes from PERSON)* |
| **DEPARTMENT** | <u>dept_id</u>, name |
| **ROOM** | <u>room_number</u>, bed_type, price, cleaning_status, availability *(derived)* |
| **STAY** (associative entity) | <u>stay_id</u>, check_in, expected_check_out, check_out, nightly_rate, status |
| **ROOM_SERVICE** | <u>order_id</u>, service_name, cost, order_date |
| **INVOICE** | <u>invoice_id</u>, issued_on, nights, room_total, service_total, grand_total *(derived: room_total + service_total)* |
| **INVOICE_ITEM** (weak entity) | line_no *(partial key, dashed underline)*, description, amount |
| **STAFF_USER** | <u>user_id</u>, username, password_hash, role |
| **AUDIT_LOG** | <u>log_id</u>, table_name, action, row_key, old_value, new_value, changed_by, changed_at |

`availability` on ROOM is dashed because it is derived from the stays (triggers keep it in step).
No multivalued or composite attributes exist in this design, so you do not need double ellipses or sub-ellipses.

## 3. Relationships (draw one diamond each, then connect)

`Double` = total participation (double line). `Single` = partial (single line).

| # | Diamond | Left entity (side, line) | Right entity (side, line) | Type |
|---|---|---|---|---|
| 1 | **IS_A** (triangle, letter `d`) | supertype **PERSON** (single line to the triangle apex) | subtypes **CUSTOMER**, **EMPLOYEE**, **DRIVER** (single line from the triangle base to each; add a small `U` or half-circle on each line pointing at PERSON if your course uses it) | specialization, disjoint |
| 2 | **WORKS_IN** | DEPARTMENT: `1`, Single | EMPLOYEE: `N`, **Double** | 1 : N |
| 3 | **MAKES** | CUSTOMER: `1`, Single | STAY: `N`, **Double** | 1 : N |
| 4 | **HOSTS** | ROOM: `1`, Single | STAY: `N`, **Double** | 1 : N |
| 5 | **ORDERS** | STAY: `1`, Single | ROOM_SERVICE: `N`, **Double** | 1 : N |
| 6 | **BILLED_BY** | STAY: `1`, Single | INVOICE: `1`, **Double** | 1 : 1 |
| 7 | **HAS_LINE** (**double diamond**, identifying) | INVOICE: `1`, **Double** | INVOICE_ITEM (weak): `N`, **Double** | 1 : N, identifying |

Reading rules of thumb for the labels: the number goes on the line **at the entity it describes how many of**. In row 2, a department has `N` employees, so put `N` near EMPLOYEE and `1` near DEPARTMENT.

### M:N through STAY
CUSTOMER and ROOM are really many-to-many (a guest stays in many rooms over time, a room hosts many guests). STAY is drawn as an **associative entity** (rectangle with a diamond inside) that carries the relationship's own attributes. Rows 3 and 4 are the two arms of that M:N.
If your course draws it the textbook way instead, delete STAY as an entity, draw one diamond **STAYS_IN** between CUSTOMER (`M`) and ROOM (`N`), and hang `stay_id, check_in, expected_check_out, check_out, nightly_rate, status` off that diamond; then ROOM_SERVICE and INVOICE attach to the diamond using an **aggregation** (a big rectangle drawn around CUSTOMER-STAYS_IN-ROOM).

### Stand-alone entities
STAFF_USER (login accounts) and AUDIT_LOG (written by triggers) have **no relationships**. Place them at the bottom edge with a small note: "no relationships by design".

## 4. Suggested layout (1 square = about 200 px on a 1600 x 1000 canvas)

Roughly left to right, top to bottom:

```
DEPARTMENT --WORKS_IN-- EMPLOYEE ---\
                                     (ISA d)--- PERSON
                       DRIVER  ------/   |
                       CUSTOMER ---------/
                          |
                        MAKES
                          |
ROOM --HOSTS-- STAY (associative) --ORDERS-- ROOM_SERVICE
                          |
                      BILLED_BY
                          |
                       INVOICE --HAS_LINE (double diamond)-- INVOICE_ITEM (weak)

STAFF_USER          AUDIT_LOG        (separate, bottom row)
```

Place attribute ellipses around each entity, spread out so connector lines do not cross. Aim for no more than 3 or 4 crossings in the whole diagram.

## 5. Build checklist

1. Draw the 12 entity shapes first (two of them special: STAY with a diamond inside, INVOICE_ITEM double rectangle).
2. Add the 7 relationship shapes (HAS_LINE as a double diamond, IS_A as a triangle).
3. Draw the connectors; make every **Double** one a double line.
4. Write `1` / `N` next to each entity end.
5. Add attribute ellipses; underline keys; dash the two derived ones (`availability`, `grand_total`); dash-underline `line_no`.
6. Add the legend (section 1) in a corner so a reader can decode the shapes.
7. Cross-check against the table below.

## 6. Cross-check against the database

| Chen element | Table / column in `hotel_mgmt` |
|---|---|
| PERSON, CUSTOMER, EMPLOYEE, DRIVER | `person`, `customer`, `employee`, `driver` (subtype `person_id` is PK **and** FK to `person`) |
| WORKS_IN | `employee.dept_id` -> `department.dept_id` (NOT NULL = total) |
| MAKES | `stay.customer_id` -> `customer.person_id` |
| HOSTS | `stay.room_number` -> `room.room_number` (+ unique key `uq_one_active_stay_per_room`) |
| ORDERS | `room_service.stay_id` -> `stay.stay_id` |
| BILLED_BY | `invoice.stay_id` UNIQUE -> `stay.stay_id` |
| HAS_LINE | `invoice_item(invoice_id, line_no)` composite PK, FK to `invoice` with ON DELETE CASCADE |

See `er_diagram.md` for the same design in crow's-foot (Mermaid) form and `normalization.md` for the normal-form reasoning.
