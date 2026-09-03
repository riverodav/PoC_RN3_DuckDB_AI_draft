-- reference view: Country
-- The published Country.parquet does not carry the reportingType attribute that
-- RN3 exposes, so it is joined with the seeded reference.CountryReportingType table.
SELECT c.countryCode
    , c.nameText
    , c.nameTextInternational
    , rt.reportingType
    , c.geometry AS geometry_polygon
FROM read_parquet('az://dis2datalake.blob.core.windows.net/test/test/Country.parquet') AS c
    LEFT JOIN reference.CountryReportingType AS rt ON rt.countryCode = c.countryCode
