-- export: monitoringresult -> SQLite
-- Requires an attached SQLite database aliased as sqlite_db.
DROP TABLE IF EXISTS sqlite_db.monitoringresult;
CREATE TABLE sqlite_db.monitoringresult AS
SELECT * FROM prefill.monitoringresult;
