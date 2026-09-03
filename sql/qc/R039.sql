SELECT
  record_id,
  thematicIdIdentifier,
  thematicIdIdentifierScheme
FROM spatial_reporting.RiverBasinDistrict
WHERE
  COALESCE(thematicIdIdentifierScheme, '') <> ''
  AND COALESCE(thematicIdIdentifier, '') = ''