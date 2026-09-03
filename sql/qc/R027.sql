WITH PredecessorsIdentifierCounter AS (
  SELECT
    X.thematicIdIdentifier,
    X.thematicIdIdentifierScheme,
    X.wiseEvolutionType,
    COUNT(*) AS quantity
  FROM (
    SELECT
      thematicIdIdentifier,
      thematicIdIdentifierScheme,
      wiseEvolutionType,
      TRIM(FLATTEN(STR_SPLIT_REGEX(predecessorsIdentifier, ',', 'ALL'))) AS onePredecessorIdentifier
    FROM spatial_reporting.RiverBasinDistrict
    WHERE
      COALESCE(predecessorsIdentifier, '') <> ''
  ) AS X
  GROUP BY
    X.thematicIdIdentifier,
    X.thematicIdIdentifierScheme,
    X.wiseEvolutionType
  UNION
  SELECT
    R.thematicIdIdentifier,
    R.thematicIdIdentifierScheme,
    R.wiseEvolutionType,
    0 AS quantity
  FROM spatial_reporting.RiverBasinDistrict AS R
  WHERE
    COALESCE(predecessorsIdentifier, '') = ''
)
SELECT
  R.record_id,
  R.thematicIdIdentifier,
  R.thematicIdIdentifierScheme,
  R.wiseEvolutionType,
  R.predecessorsIdentifier
FROM spatial_reporting.RiverBasinDistrict AS R
JOIN PredecessorsIdentifierCounter AS P
  ON P.thematicIdIdentifier = R.thematicIdIdentifier
  AND P.thematicIdIdentifierScheme = R.thematicIdIdentifierScheme
WHERE
  R.wiseEvolutionType IN ('aggregation', 'changeBothAggregationAndSplitting')
  AND P.quantity < 2