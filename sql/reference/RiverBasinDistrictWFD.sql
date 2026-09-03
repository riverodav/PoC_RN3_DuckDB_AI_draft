-- reference view: RiverBasinDistrictWFD
-- Previous reporting cycle used by RN3 as reference data for cross-checks.
-- Parameterised by the session variable reference_cycle_year.
SELECT geometry AS geometry_polygon
    , inspireIdLocalId
    , inspireIdNamespace
    , inspireIdVersionId
    , thematicIdIdentifier
    , thematicIdIdentifierScheme
    , beginLifespanVersion
    , endLifespanVersion
    , predecessorsIdentifier
    , predecessorsIdentifierScheme
    , successorsIdentifier
    , successorsIdentifierScheme
    , wiseEvolutionType
    , nameTextInternational
    , nameText
    , nameLanguage
    , designationPeriodBegin
    , designationPeriodEnd
    , zoneType
    , legalBasisName
    , legalBasisLink
    , legalBasisLevel
    , link
    , statusCode
    , countryCode
    , cYear
FROM read_parquet('az://dis2datalake.blob.core.windows.net/test/test/SPATIAL_RiverBasinDistrict/*/*/*.parquet', hive_partitioning = true)
WHERE CAST(cYear AS VARCHAR) = getvariable('reference_cycle_year')
