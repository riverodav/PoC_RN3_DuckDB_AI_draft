WITH OnePredecessorIdentifier AS (
  SELECT
    record_id,
    thematicIdIdentifier,
    thematicIdIdentifierScheme,
    TRIM(FLATTEN(STR_SPLIT_REGEX(predecessorsIdentifier, ','))) AS onePredecessorIdentifier,
    predecessorsIdentifierScheme
  FROM spatial_reporting.RiverBasinDistrict
)
SELECT
  record_id,
  thematicIdIdentifier,
  thematicIdIdentifierScheme
FROM OnePredecessorIdentifier
WHERE
  onePredecessorIdentifier = thematicIdIdentifier
  AND thematicIdIdentifierScheme = 'euRBDCode'