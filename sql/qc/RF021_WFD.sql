SELECT
  record_id,
  thematicIdIdentifier
FROM spatial_reporting.RiverBasinDistrict AS S /* Spatial */
/* This QC is for countries reporting under WFD only */
WHERE
  EXISTS(
    SELECT
      0
    FROM reference.Country AS C
    WHERE
      countryCode = getvariable('country_code') AND reportingType = 'WFD'
  )
  AND EXISTS(
    SELECT
      0
    FROM reference.RiverBasinDistrictWFD AS R /* Reference */
    WHERE
      R.countryCode = getvariable('country_code')
      AND R.thematicIdIdentifier = S.thematicIdIdentifier
      AND statusCode = 'superseded'
  )