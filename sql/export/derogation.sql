-- export: derogation -> SQLite
-- Requires an attached SQLite database aliased as sqlite_db.
DROP TABLE IF EXISTS sqlite_db.derogation;
CREATE TABLE sqlite_db.derogation AS
SELECT * FROM prefill.derogation;
