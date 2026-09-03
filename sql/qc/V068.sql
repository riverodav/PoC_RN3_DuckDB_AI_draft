SELECT
  record_id,
  wiseEvolutionType
FROM spatial_reporting.RiverBasinDistrict
WHERE
  wiseEvolutionType = 'deletion'