SELECT
  record_id,
  thematicIdIdentifier,
  thematicIdIdentifierScheme,
  wiseEvolutionType
FROM spatial_reporting.RiverBasinDistrict
WHERE
  wiseEvolutionType IN ('changeCode', 'splitting')
  AND (
    STRPOS(predecessorsIdentifier, ',') > 0
    OR COALESCE(predecessorsIdentifier, '') = ''
  )