-- export: CompetentAuthority -> SQLite
-- Requires an attached SQLite database aliased as sqlite_db.
DROP TABLE IF EXISTS sqlite_db.CompetentAuthority;
CREATE TABLE sqlite_db.CompetentAuthority AS
SELECT euCACode
    , competentAuthorityName
    , competentAuthorityNameNL
    , competentAuthorityNameNLLanguage
    , acronym
    , street
    , city
    , country
    , postCode
    , url
    , record_id
FROM prefill.CompetentAuthority;
