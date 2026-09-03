SELECT
  R.record_id,
  R.thematicIdIdentifier,
  R.wiseEvolutionType
FROM spatial_reporting.RiverBasinDistrict AS R
WHERE
  EXISTS(
    SELECT
      0
    FROM reference.RiverBasinDistrictWFD AS RF
    WHERE
      RF.thematicIdIdentifier = R.thematicIdIdentifier
      AND RF.thematicIdIdentifierScheme = R.thematicIdIdentifierScheme
      AND RF.countryCode = getvariable('country_code')
  )
  AND NOT wiseEvolutionType IN ('noChange', 'change')