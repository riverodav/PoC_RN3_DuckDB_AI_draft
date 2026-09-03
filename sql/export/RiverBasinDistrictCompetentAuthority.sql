-- export: RiverBasinDistrictCompetentAuthority -> SQLite
-- Requires an attached SQLite database aliased as sqlite_db.
DROP TABLE IF EXISTS sqlite_db.RiverBasinDistrictCompetentAuthority;
CREATE TABLE sqlite_db.RiverBasinDistrictCompetentAuthority AS
SELECT euRBDCode
    , euCACode
    , mainRole
    , record_id
FROM prefill.RiverBasinDistrictCompetentAuthority;
