WITH IndividualPredecessor AS (
  SELECT
    TRIM(FLATTEN(STR_SPLIT_REGEX(predecessorsIdentifier, ',', 'ALL'))) AS predecessor,
    predecessorsIdentifier,
    thematicIdIdentifier,
    wiseEvolutionType,
    record_id
  FROM spatial_reporting.RiverBasinDistrict /* Spatial */
  WHERE
    COALESCE(predecessorsIdentifier, '') <> ''
    AND wiseEvolutionType IN ('splitting', 'changeBothAggregationAndSplitting')
), UniquePredecessor AS (
  SELECT
    predecessor
  FROM IndividualPredecessor
  GROUP BY
    predecessor
  HAVING
    COUNT(*) = 1
)
SELECT DISTINCT
  P1.record_id,
  P1.thematicIdIdentifier
FROM IndividualPredecessor AS P1
JOIN UniquePredecessor AS P2
  ON P2.predecessor = P1.predecessor