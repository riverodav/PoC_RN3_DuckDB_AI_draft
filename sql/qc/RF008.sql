/* The object has a predecessor that does not exist in the register. */
WITH IndividualPredecessor AS (
  SELECT
    S.record_id,
    S.thematicIdIdentifier,
    S.predecessorsIdentifierScheme,
    TRIM(FLATTEN(STR_SPLIT_REGEX(S.predecessorsIdentifier, ',', 'ALL'))) AS onePredecessorIdentifier
  FROM spatial_reporting.RiverBasinDistrict AS S /* Spatial */
  WHERE
    COALESCE(S.predecessorsIdentifier, '') <> '' /* Avoids values not reported */
    AND LEFT(S.thematicIdIdentifier, 2) = getvariable('country_code')
)
SELECT
  record_id,
  thematicIdIdentifier,
  ARRAY_TO_STRING(ARRAY_AGG(onePredecessorIdentifier), ', ') AS predecessorsIdentifier
FROM IndividualPredecessor
GROUP BY
  record_id,
  thematicIdIdentifier
HAVING
  COUNT(*) > 0