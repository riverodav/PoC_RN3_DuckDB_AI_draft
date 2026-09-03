/*
    T002_WFD - every reference RBD must be reported again or declared as a predecessor.
    Adapted from transpile_qcs/translated_qcs/T002_WFD.sql for the local DuckDB runtime:
      - the RN3 placeholder {%R3_COUNTRY_CODE%} is replaced by getvariable('country_code');
      - the transpiled TRIM(FLATTEN(STR_SPLIT_REGEX(...))) is rewritten as a lateral UNNEST,
        which is the DuckDB idiom for exploding the comma separated predecessors list.
*/
WITH predecessors AS (
  SELECT
    TRIM(p.predecessor) AS predecessor,
    MS.thematicIdIdentifierScheme
  FROM spatial_reporting.RiverBasinDistrict AS MS,
    UNNEST(STR_SPLIT(MS.predecessorsIdentifier, ',')) AS p(predecessor)
  WHERE
    COALESCE(MS.predecessorsIdentifier, '') <> ''
)
SELECT
  X.record_id,
  CASE
    WHEN LENGTH(X.ids) > 4000
    THEN CONCAT(LEFT(X.ids, 4000 - STRPOS(REVERSE(LEFT(X.ids, 4000)), ',')), '...')
    ELSE X.ids
  END AS identifiers,
  X.numberOfRecords
FROM (
  SELECT
    (SELECT MIN(record_id) FROM spatial_reporting.RiverBasinDistrict) AS record_id,
    LISTAGG(RF.thematicIdIdentifier, ', ') AS ids,
    COUNT(*) AS numberOfRecords
  FROM reference.RiverBasinDistrictWFD AS RF
  LEFT JOIN spatial_reporting.RiverBasinDistrict AS D
    ON D.thematicIdIdentifier = RF.thematicIdIdentifier
    AND D.thematicIdIdentifierScheme = RF.thematicIdIdentifierScheme
  LEFT JOIN predecessors AS P
    ON P.predecessor = RF.thematicIdIdentifier
    AND P.thematicIdIdentifierScheme = RF.thematicIdIdentifierScheme
  WHERE
    EXISTS( /* this QC applies to countries reporting under WFD only */
      SELECT 1
      FROM reference.Country AS C
      WHERE C.countryCode = getvariable('country_code') AND C.reportingType = 'WFD'
    )
    AND RF.countryCode = getvariable('country_code')
    AND RF.statusCode IN ('valid', 'stable')
    AND D.thematicIdIdentifier IS NULL
    AND P.predecessor IS NULL
  HAVING
    COUNT(*) > 0
) AS X
