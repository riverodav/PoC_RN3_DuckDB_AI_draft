-- export: parameter -> SQLite
-- Requires an attached SQLite database aliased as sqlite_db.
DROP TABLE IF EXISTS sqlite_db.parameter;
CREATE TABLE sqlite_db.parameter AS
SELECT * FROM prefill.parameter;
