-- export: qualityandmonitoring -> SQLite
-- Requires an attached SQLite database aliased as sqlite_db.
DROP TABLE IF EXISTS sqlite_db.qualityandmonitoring;
CREATE TABLE sqlite_db.qualityandmonitoring AS
SELECT * FROM prefill.qualityandmonitoring;
