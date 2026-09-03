WITH OnePredecessor AS (
  SELECT
    TRIM(FLATTEN(STR_SPLIT_REGEX(predecessorsIdentifier, ',', 'ALL'))) AS onePredecessor,
    record_id
  FROM spatial_reporting.RiverBasinDistrict
  WHERE
    COALESCE(predecessorsIdentifier, '') <> ''
), InvalidIdentifiers AS (
  SELECT
    LISTAGG(R.thematicIdIdentifier, ', ') AS ids
  FROM spatial_reporting.RiverBasinDistrict AS R
  JOIN OnePredecessor AS P
    ON P.onePredecessor = R.thematicIdIdentifier
  HAVING
    COUNT(*) > 0
)
SELECT
  (
    SELECT
      record_id
    FROM spatial_reporting.RiverBasinDistrict
    LIMIT 1
  ) AS record_id,
  CASE
    WHEN LENGTH(ids) > 4000
    THEN CONCAT(LEFT(LEFT(ids, 4000), 4000 - STRPOS(REVERSE(LEFT(ids, 4000)), ',') + 1), '...')
    ELSE ids
  END AS IDENTIFIERS
FROM InvalidIdentifiers