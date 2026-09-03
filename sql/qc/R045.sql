SELECT
  record_id,
  predecessorsIdentifier,
  wiseEvolutionType
FROM spatial_reporting.RiverBasinDistrict
WHERE
  NOT wiseEvolutionType IN ('creation', 'change', 'noChange')
  AND COALESCE(predecessorsIdentifier, '') = ''