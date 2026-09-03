/*
    RF012_WFD - designationPeriodBegin must match the value held in the reference data.
    Adapted from transpile_qcs/translated_qcs/RF012_WFD.sql for the local DuckDB runtime:
      - the RN3 placeholder {%R3_COUNTRY_CODE%} is replaced by getvariable('country_code');
      - reference.Country / reference.RiverBasinDistrictWFD are catalog views.
*/
WITH BothDates AS (
  SELECT
    S.record_id,
    S.thematicIdIdentifier,
    S.wiseEvolutionType,
    CAST(S.designationPeriodBegin AS DATE) AS descriptiveDate,
    CAST(R.designationPeriodBegin AS DATE) AS referenceDate
  FROM spatial_reporting.RiverBasinDistrict AS S /* reported */
  JOIN reference.RiverBasinDistrictWFD AS R /* reference */
    ON R.thematicIdIdentifier = S.thematicIdIdentifier
    AND R.thematicIdIdentifierScheme = S.thematicIdIdentifierScheme
  WHERE
    S.wiseEvolutionType IN ('deletion', 'change', 'noChange')
    AND R.countryCode = getvariable('country_code')
    AND EXISTS( /* this QC applies to countries reporting under WFD only */
      SELECT 1
      FROM reference.Country AS C
      WHERE C.countryCode = getvariable('country_code') AND C.reportingType = 'WFD'
    )
    AND COALESCE(S.designationPeriodBegin, '') <> '' /* avoids values not reported */
    AND COALESCE(R.designationPeriodBegin, '') <> ''
)
SELECT
  record_id,
  thematicIdIdentifier,
  wiseEvolutionType,
  descriptiveDate,
  referenceDate
FROM BothDates
WHERE
  descriptiveDate IS NOT NULL
  AND referenceDate IS NOT NULL
  AND referenceDate <> descriptiveDate
