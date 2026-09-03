-- reference view: ProtectedAreaWFD
-- Previous reporting cycle used by RN3 as reference data for cross-checks.
-- Parameterised by the session variable reference_cycle_year.
SELECT thematicIdIdentifier
    , thematicIdIdentifierScheme
    , relatedzoneidentifier
    , relatedzoneidentifierscheme
    , geometry_polygon
    , geometry_point
    , geometry_line
    , countryCode
    , cYear
FROM read_parquet('az://dis2datalake.blob.core.windows.net/test/test/SPATIAL_ProtectedArea/*/*/*.parquet', hive_partitioning = true)
WHERE CAST(cYear AS VARCHAR) = getvariable('reference_cycle_year')
