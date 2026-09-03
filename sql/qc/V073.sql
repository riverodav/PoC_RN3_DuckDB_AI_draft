SELECT
  record_id,
  predecessorsIdentifierScheme
FROM spatial_reporting.RiverBasinDistrict
WHERE
  COALESCE(predecessorsIdentifierScheme, '') <> ''
  AND predecessorsIdentifierScheme <> 'euRBDCode'