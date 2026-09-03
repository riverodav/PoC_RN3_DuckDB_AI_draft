-- prefill view: SPATIAL_ProtectedArea (spatial)
-- Parameterised by the session variables country_code and cycle_year.
-- Geometry priority polygon > point > line is applied at export time, not here.
SELECT thematicIdIdentifier
    , thematicIdIdentifierScheme
    , relatedzoneidentifier
    , relatedzoneidentifierscheme
    , geometry_polygon
    , geometry_point
    , geometry_line
    , stable_record_id('SPATIAL_ProtectedArea|' || countryCode || '|' || thematicIdIdentifier || '|' || COALESCE(relatedzoneidentifier, '')) AS record_id
FROM read_parquet('az://dis2datalake.blob.core.windows.net/test/test/SPATIAL_ProtectedArea/*/*/*.parquet', hive_partitioning = true)
WHERE CAST(cYear AS VARCHAR) = getvariable('cycle_year')
  AND countryCode = getvariable('country_code')
