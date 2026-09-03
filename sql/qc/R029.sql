WITH IndividualSuccessor AS (
  SELECT
    TRIM(FLATTEN(STR_SPLIT_REGEX(successorsIdentifier, ',', 'ALL'))) AS successor,
    thematicIdIdentifier,
    wiseEvolutionType,
    record_id
  FROM spatial_reporting.RiverBasinDistrict /* Spatial */
  WHERE
    COALESCE(successorsIdentifier, '') <> ''
)
SELECT DISTINCT
  IP.record_id,
  IP.thematicIdIdentifier
FROM IndividualSuccessor AS IP
JOIN (
  SELECT
    thematicIdIdentifier
  FROM IndividualSuccessor
  GROUP BY
    thematicIdIdentifier
  HAVING
    COUNT(*) >= 2
) AS IP2
  ON IP.thematicIdIdentifier = IP2.thematicIdIdentifier
WHERE
  NOT wiseEvolutionType IN ('splitting', 'changeBothAggregationAndSplitting')