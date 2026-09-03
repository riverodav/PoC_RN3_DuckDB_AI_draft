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
)
SELECT DISTINCT
  P1.record_id,
  P1.thematicIdIdentifier
FROM IndividualPredecessor AS P1
JOIN IndividualPredecessor AS P2
  ON P2.predecessor = P1.predecessor
  AND P1.thematicIdIdentifier <> P2.thematicIdIdentifier
WHERE
  P1.wiseEvolutionType = 'changeCode'