WITH IndividualPredecessor AS (
  SELECT
    S.record_id,
    S.thematicIdIdentifier,
    S.thematicIdIdentifierScheme,
    S.wiseEvolutionType,
    CAST(S.designationPeriodBegin AS DATE) AS descriptiveDate,
    TRIM(FLATTEN(STR_SPLIT_REGEX(predecessorsIdentifier, ',', 'ALL'))) AS onePredecessorIdentifier
  FROM spatial_reporting.RiverBasinDistrict AS S /* Spatial */
  WHERE
    S.wiseEvolutionType = 'changeCode'
    AND LEFT(S.thematicIdIdentifier, 2) = getvariable('country_code')
    AND /* Avoids values not reported */ COALESCE(S.designationPeriodBegin, '') <> ''
    AND /* This QC is for countries reporting under WFD only */ EXISTS(
      SELECT
        0
      FROM reference.Country AS C
      WHERE
        countryCode = getvariable('country_code') AND reportingType = 'WFD'
    )
), PredecessorsInReference AS (
  SELECT
    IP.record_id,
    IP.thematicIdIdentifier,
    IP.wiseEvolutionType,
    IP.descriptiveDate,
    IP.onePredecessorIdentifier,
    CAST(R.designationPeriodBegin AS DATE) AS referenceDate
  FROM IndividualPredecessor AS IP
  JOIN reference.RiverBasinDistrictWFD AS R /* Reference */
    ON R.thematicIdIdentifier = IP.onePredecessorIdentifier
    AND R.thematicIdIdentifierScheme = IP.thematicIdIdentifierScheme
  WHERE
    NOT IP.descriptiveDate IS NULL AND R.countryCode = getvariable('country_code')
)
SELECT
  record_id,
  thematicIdIdentifier,
  onePredecessorIdentifier AS predecessorIdentifier,
  wiseEvolutionType,
  descriptiveDate,
  referenceDate
FROM PredecessorsInReference
WHERE
  NOT referenceDate IS NULL AND descriptiveDate <> referenceDate