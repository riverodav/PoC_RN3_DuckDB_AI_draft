WITH OnePredecessor AS (
  SELECT
    record_id,
    thematicIdIdentifier,
    thematicIdIdentifierScheme,
    TRIM(FLATTEN(STR_SPLIT_REGEX(predecessorsIdentifier, ',', 'ALL'))) AS onePredecessorIdentifier,
    CAST(designationPeriodBegin AS DATE) AS dateValue
  FROM spatial_reporting.RiverBasinDistrict
  /* Avoids values not reported */
  WHERE
    COALESCE(predecessorsIdentifier, '') <> ''
    AND COALESCE(designationPeriodBegin, '') <> ''
), PredecessorsDifferentDate AS (
  SELECT DISTINCT
    P1.onePredecessorIdentifier
  FROM OnePredecessor AS P1
  JOIN OnePredecessor AS P2
    ON P1.onePredecessorIdentifier = P2.onePredecessorIdentifier
    AND (
      P1.thematicIdIdentifier <> P2.thematicIdIdentifier
      OR P1.thematicIdIdentifierScheme <> P2.thematicIdIdentifierScheme
    )
    AND P1.dateValue <> P2.dateValue
)
SELECT
  OP.record_id,
  OP.thematicIdIdentifier,
  OP.thematicIdIdentifierScheme,
  LISTAGG(CONCAT('[', OP.onePredecessorIdentifier, ' / ', OP.dateValue, ']'), ', ') AS RECORDS
FROM OnePredecessor AS OP
JOIN PredecessorsDifferentDate AS PDD
  ON PDD.onePredecessorIdentifier = OP.onePredecessorIdentifier
GROUP BY
  OP.record_id,
  OP.thematicIdIdentifier,
  OP.thematicIdIdentifierScheme
HAVING
  COUNT(*) > 0