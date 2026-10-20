-- 12_audit_log.sql  (DDL)
-- Filled automatically by triggers (30_triggers.sql): room changes, employee/customer deletes.
-- No foreign keys on purpose: the log must survive deletion of the rows it describes.

USE hotel_mgmt;

CREATE TABLE IF NOT EXISTS audit_log (
    log_id     BIGINT       NOT NULL AUTO_INCREMENT,
    table_name VARCHAR(40)  NOT NULL,
    action     VARCHAR(10)  NOT NULL,
    row_key    VARCHAR(60),
    old_value  TEXT,
    new_value  TEXT,
    changed_by VARCHAR(100),
    changed_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (log_id),
    KEY idx_audit_table_time (table_name, changed_at)
) ENGINE=InnoDB;
