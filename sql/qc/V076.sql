SELECT
  R.record_id,
  R.thematicIdIdentifierScheme
FROM spatial_reporting.RiverBasinDistrict AS R
WHERE
  (
    COALESCE(R.thematicIdIdentifierScheme, '') <> 'euRBDCode'
    AND EXISTS(
      SELECT
        0
      FROM reference.Country
      WHERE
        countryCode = getvariable('country_code') AND reportingType = 'WFD'
    )
  )
  OR (
    COALESCE(R.thematicIdIdentifierScheme, '') <> 'eionetRBDCode'
    AND EXISTS(
      SELECT
        0
      FROM reference.Country
      WHERE
        countryCode = getvariable('country_code') AND reportingType = 'WISE5'
    )
  )