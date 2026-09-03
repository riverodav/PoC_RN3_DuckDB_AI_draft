SELECT
  record_id,
  predecessorsIdentifier,
  wiseEvolutionType
FROM spatial_reporting.RiverBasinDistrict
WHERE
  wiseEvolutionType IN ('creation', 'noChange')
  AND COALESCE(predecessorsIdentifier, '') <> ''