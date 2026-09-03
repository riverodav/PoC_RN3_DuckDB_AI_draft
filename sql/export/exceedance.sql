-- export: exceedance -> SQLite
-- Requires an attached SQLite database aliased as sqlite_db.
DROP TABLE IF EXISTS sqlite_db.exceedance;
CREATE TABLE sqlite_db.exceedance AS
SELECT * FROM prefill.exceedance;
