SELECT
  record_id,
  wiseEvolutionType,
  inspireIdVersionId
FROM spatial_reporting.RiverBasinDistrict
WHERE
  wiseEvolutionType = 'change' AND COALESCE(inspireIdVersionId, '') = ''