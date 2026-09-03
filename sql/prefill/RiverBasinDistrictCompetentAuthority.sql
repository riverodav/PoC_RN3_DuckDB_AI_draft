-- prefill view: RiverBasinDistrictCompetentAuthority (descriptive)
-- Parameterised by the session variables country_code and cycle_year.
WITH ca_roles AS (
    SELECT DISTINCT euRBDCode
        , euCACode
        , mainRole AS rawRole
    FROM 'https://dis2datalake.blob.core.windows.net/discodata/wise_wfd/v2r1/rbdsuca_rbd_primecompetentauthority.parquet' AS pca
        JOIN 'https://dis2datalake.blob.core.windows.net/discodata/wise_wfd/v2r1/rbdsuca_competentauthority_mainrole.parquet' AS ca_main
          ON pca.primeCompetentAuthority = ca_main.euCACode
         AND pca.cYear = ca_main.cYear
    WHERE CAST(ca_main.cYear AS VARCHAR) = getvariable('cycle_year')
      AND ca_main.countryCode = getvariable('country_code')

    UNION

    SELECT DISTINCT euRBDCode
        , euCACode
        , mainRole AS rawRole
    FROM 'https://dis2datalake.blob.core.windows.net/discodata/wise_wfd/v2r1/rbdsuca_rbd_othercompetentauthority.parquet' AS oca
        JOIN 'https://dis2datalake.blob.core.windows.net/discodata/wise_wfd/v2r1/rbdsuca_competentauthority_mainrole.parquet' AS ca_main
          ON oca.otherCompetentAuthority = ca_main.euCACode
         AND oca.cYear = ca_main.cYear
    WHERE CAST(ca_main.cYear AS VARCHAR) = getvariable('cycle_year')
      AND ca_main.countryCode = getvariable('country_code')

    UNION

    SELECT DISTINCT euRBDCode
        , euCACode
        , otherRole AS rawRole
    FROM 'https://dis2datalake.blob.core.windows.net/discodata/wise_wfd/v2r1/rbdsuca_rbd_primecompetentauthority.parquet' AS pca
        JOIN 'https://dis2datalake.blob.core.windows.net/discodata/wise_wfd/v2r1/rbdsuca_competentauthority_otherrole.parquet' AS ca_other
          ON pca.primeCompetentAuthority = ca_other.euCACode
         AND pca.cYear = ca_other.cYear
    WHERE CAST(ca_other.cYear AS VARCHAR) = getvariable('cycle_year')
      AND ca_other.otherRole IS NOT NULL
      AND ca_other.countryCode = getvariable('country_code')

    UNION

    SELECT DISTINCT euRBDCode
        , euCACode
        , otherRole AS rawRole
    FROM 'https://dis2datalake.blob.core.windows.net/discodata/wise_wfd/v2r1/rbdsuca_rbd_othercompetentauthority.parquet' AS oca
        JOIN 'https://dis2datalake.blob.core.windows.net/discodata/wise_wfd/v2r1/rbdsuca_competentauthority_otherrole.parquet' AS ca_other
          ON oca.otherCompetentAuthority = ca_other.euCACode
         AND oca.cYear = ca_other.cYear
    WHERE CAST(ca_other.cYear AS VARCHAR) = getvariable('cycle_year')
      AND ca_other.otherRole IS NOT NULL
      AND ca_other.countryCode = getvariable('country_code')
)
SELECT euRBDCode
    , euCACode
    , CASE WHEN rawRole = '1 - Pressure and impact analysis' THEN 'pressureAndImpactAnalysis'
           WHEN rawRole = '2 - Economic analysis' THEN 'economicAnalysis'
           WHEN rawRole = '3 - Monitoring of surface water' THEN 'monitoringOfSurfaceWater'
           WHEN rawRole = '4 - Monitoring of groundwater' THEN 'monitoringOfGroundwater'
           WHEN rawRole = '5 - Assessment of status of surface water' THEN 'assessmentOfStatusOfSurfaceWater'
           WHEN rawRole = '6 - Assessment of status of groundwater' THEN 'assessmentOfStatusOfGroundwater'
           WHEN rawRole = '7 - Preparation of RBMP' THEN 'preparationOfRBMP'
           WHEN rawRole = '8 - Preparation of PoM' THEN 'preparationOfProgrammeOfMeasures'
           WHEN rawRole = '9 - Implementation of measures' THEN 'implementationOfMeasures'
           WHEN rawRole = '10 - Public participation' THEN 'publicParticipation'
           WHEN rawRole = '11 - Enforcement of regulations' THEN 'enforcementOfRegulations'
           WHEN rawRole = '12 - Co-ordination of implementation' THEN 'coordinationOfImplementation'
           WHEN rawRole = '13 - Reporting to the European Commission' THEN 'reportingToTheEuropeanCommission'
           ELSE NULL
      END AS mainRole
    , stable_record_id('RiverBasinDistrictCompetentAuthority|' || euRBDCode || '|' || euCACode || '|' || COALESCE(rawRole, '')) AS record_id
FROM ca_roles
