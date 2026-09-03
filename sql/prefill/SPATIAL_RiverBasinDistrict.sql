-- prefill view: SPATIAL_RiverBasinDistrict (spatial)
-- Parameterised by the session variables country_code and cycle_year.
-- The source geometry is already typed GEOMETRY with SRID EPSG:3035.
WITH international_rbds AS (
    SELECT euRBDCode
        , internationalRBD
    FROM 'https://dis2datalake.blob.core.windows.net/discodata/wise_wfd/v2r1/rbdsuca_rbd.parquet'
    WHERE CAST(cYear AS VARCHAR) = getvariable('cycle_year')
      AND countryCode = getvariable('country_code')
)
SELECT rbd.geometry AS geometry_polygon
    , rbd.inspireIdLocalId
    , rbd.inspireIdNamespace
    , rbd.inspireIdVersionId
    , rbd.thematicIdIdentifier
    , rbd.thematicIdIdentifierScheme
    , rbd.beginLifespanVersion
    , rbd.endLifespanVersion
    , rbd.predecessorsIdentifier
    , rbd.predecessorsIdentifierScheme
    , rbd.successorsIdentifier
    , rbd.successorsIdentifierScheme
    , rbd.wiseEvolutionType
    , rbd.nameTextInternational
    , rbd.nameText
    , rbd.nameLanguage
    , rbd.designationPeriodBegin
    , rbd.designationPeriodEnd
    , rbd.zoneType
    , CASE WHEN international_rbds.internationalRBD = 'Yes' THEN 'internationalRiverBasinDistrict'
           WHEN international_rbds.internationalRBD = 'No' THEN 'nationalRiverBasinDistrict'
           ELSE NULL
      END AS specialisedZoneType
    , rbd.legalBasisName
    , rbd.legalBasisLink
    , rbd.legalBasisLevel
    , rbd.link
    , stable_record_id('SPATIAL_RiverBasinDistrict|' || rbd.countryCode || '|' || rbd.thematicIdIdentifier || '|' || COALESCE(rbd.inspireIdLocalId, '')) AS record_id
FROM read_parquet('az://dis2datalake.blob.core.windows.net/test/test/SPATIAL_RiverBasinDistrict/*/*/*.parquet', hive_partitioning = true) AS rbd
    LEFT JOIN international_rbds ON international_rbds.euRBDCode = rbd.thematicIdIdentifier
WHERE CAST(rbd.cYear AS VARCHAR) = getvariable('cycle_year')
  AND rbd.countryCode = getvariable('country_code')
