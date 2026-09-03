SELECT
  record_id,
  predecessorsIdentifier,
  wiseEvolutionType
FROM spatial_reporting.RiverBasinDistrict
WHERE
  wiseEvolutionType = 'creation' AND COALESCE(predecessorsIdentifier, '') <> ''