SELECT
  R.record_id,
  R.thematicIdIdentifier,
  R.wiseEvolutionType
FROM spatial_reporting.RiverBasinDistrict AS R
WHERE
  EXISTS(
    SELECT
      0
    FROM reference.Country
    WHERE
      countryCode = getvariable('country_code') AND reportingType = 'WFD'
  )
  AND NOT EXISTS(
    SELECT
      0
    FROM reference.RiverBasinDistrictWFD AS RF
    WHERE
      RF.thematicIdIdentifier = R.thematicIdIdentifier
      AND RF.thematicIdIdentifierScheme = R.thematicIdIdentifierScheme
      AND RF.countryCode = getvariable('country_code')
      AND RF.wiseEvolutionType <> 'deletion'
  )
  AND wiseEvolutionType IN ('noChange', 'change')