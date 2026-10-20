-- 70_tcl_acid_demo.sql  (TCL + ACID demonstration)
-- Works on its own scratch table `acid_account` (dropped at the end), so it never touches hotel data,
-- except section F which only READS.
-- Run it in Workbench section by section (select the lines, press Ctrl+Enter) to watch each result.
--
-- ACID:  A = Atomicity   (all of a transaction or none of it)
--        C = Consistency (constraints are never violated, even by a "committed" change)
--        I = Isolation   (concurrent transactions do not see each other's half-done work)
--        D = Durability  (once COMMIT returns, the data survives a crash)

USE hotel_mgmt;

DROP TABLE IF EXISTS acid_account;
CREATE TABLE acid_account (
    acc_id  INT           NOT NULL PRIMARY KEY,
    balance DECIMAL(10,2) NOT NULL,
    CONSTRAINT chk_acid_balance CHECK (balance >= 0)
) ENGINE=InnoDB;                       -- InnoDB is the engine that supports transactions
INSERT INTO acid_account VALUES (1, 1000.00), (2, 500.00);

-- ---------- A. Atomicity: COMMIT makes both steps permanent together ----------
SET autocommit = 0;                    -- or simply use START TRANSACTION
START TRANSACTION;
UPDATE acid_account SET balance = balance - 300 WHERE acc_id = 1;
UPDATE acid_account SET balance = balance + 300 WHERE acc_id = 2;
COMMIT;
SELECT * FROM acid_account;            -- 700 / 800

-- ---------- B. ROLLBACK undoes everything since START TRANSACTION ----------
START TRANSACTION;
UPDATE acid_account SET balance = balance - 100 WHERE acc_id = 1;
SELECT * FROM acid_account;            -- account 1 shows 600 inside the transaction
ROLLBACK;
SELECT * FROM acid_account;            -- back to 700

-- ---------- C. SAVEPOINT: undo only part of a transaction ----------
START TRANSACTION;
UPDATE acid_account SET balance = balance + 50 WHERE acc_id = 1;      -- step 1 (kept)
SAVEPOINT after_step_1;
UPDATE acid_account SET balance = balance - 400 WHERE acc_id = 2;     -- step 2 (undone)
ROLLBACK TO SAVEPOINT after_step_1;
COMMIT;
SELECT * FROM acid_account;            -- 750 / 800
SET autocommit = 1;

-- ---------- D. Consistency: a change that breaks a rule is rejected AND rolled back ----------
DELIMITER $$
DROP PROCEDURE IF EXISTS acid_try_overdraw$$
CREATE PROCEDURE acid_try_overdraw()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'REJECTED: balance cannot go below 0 - the whole transfer was rolled back' AS result;
    END;
    START TRANSACTION;
    UPDATE acid_account SET balance = balance + 5000 WHERE acc_id = 2;   -- this step would be fine...
    UPDATE acid_account SET balance = balance - 5000 WHERE acc_id = 1;   -- ...this one violates the CHECK
    COMMIT;
    SELECT 'committed' AS result;
END$$
DELIMITER ;
CALL acid_try_overdraw();
SELECT * FROM acid_account;            -- unchanged: 750 / 800 (the +5000 on account 2 was undone too)
DROP PROCEDURE acid_try_overdraw;

-- ---------- E. Isolation: two sessions at once ----------
-- Open TWO query tabs in Workbench (two separate connections) and run these in order:
--   Tab 1:  START TRANSACTION;
--           SELECT balance FROM acid_account WHERE acc_id = 1 FOR UPDATE;   -- locks the row
--   Tab 2:  START TRANSACTION;
--           SELECT balance FROM acid_account WHERE acc_id = 1 FOR UPDATE;   -- WAITS (blocked) ...
--   Tab 1:  UPDATE acid_account SET balance = balance - 10 WHERE acc_id = 1;
--           COMMIT;                                                         -- ... Tab 2 now continues and sees 740
--   Tab 2:  COMMIT;
-- This is exactly how sp_check_in stops two receptionists booking the same room: it runs
-- SELECT ... FROM room WHERE room_number = ? FOR UPDATE, so the second caller waits and then sees "Occupied".
SELECT @@transaction_isolation AS current_isolation_level;   -- MySQL default: REPEATABLE-READ
-- Levels you can set for your session: READ UNCOMMITTED, READ COMMITTED, REPEATABLE READ, SERIALIZABLE
--   SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- ---------- F. Durability ----------
-- InnoDB writes every committed change to its redo log before COMMIT returns. After a crash, MySQL replays
-- the log on restart, so committed data is not lost and half-finished transactions are discarded.
SHOW VARIABLES LIKE 'innodb_flush_log_at_trx_commit';   -- 1 = flush to disk at every COMMIT (full durability)
SHOW VARIABLES LIKE 'default_storage_engine';

-- ---------- G. The hotel procedures are atomic too ----------
-- Needs the sample data (61_sample_data.sql): tries to book an occupied room and shows that nothing was half-saved.
DELIMITER $$
DROP PROCEDURE IF EXISTS acid_try_double_booking$$
CREATE PROCEDURE acid_try_double_booking()
BEGIN
    DECLARE v_room VARCHAR(20) DEFAULT NULL;
    DECLARE v_before INT;
    DECLARE v_after INT;
    DECLARE v_msg TEXT DEFAULT NULL;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
    END;
    SELECT room_number INTO v_room FROM room WHERE availability = 'Occupied' LIMIT 1;
    IF v_room IS NULL THEN
        SELECT 'No occupied room found - run 61_sample_data.sql first' AS result;
    ELSE
        SELECT COUNT(*) INTO v_before FROM person;
        CALL sp_check_in('Double Booker', '0000000000', '', v_room, NULL);
        SELECT COUNT(*) INTO v_after FROM person;
        SELECT v_room AS room, v_msg AS error_raised, v_before AS persons_before, v_after AS persons_after;
    END IF;
END$$
DELIMITER ;
CALL acid_try_double_booking();
DROP PROCEDURE acid_try_double_booking;

-- ---------- clean up ----------
DROP TABLE acid_account;
