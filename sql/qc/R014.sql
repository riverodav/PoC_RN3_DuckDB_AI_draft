SELECT
  record_id,
  predecessorsIdentifier,
  predecessorsIdentifierScheme
FROM spatial_reporting.RiverBasinDistrict
WHERE
  COALESCE(predecessorsIdentifierScheme, '') <> ''
  AND COALESCE(predecessorsIdentifier, '') = ''