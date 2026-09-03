SELECT
  X.record_id,
  CASE
    WHEN LENGTH(X.ids) > 4000
    THEN CONCAT(LEFT(LEFT(X.ids, 4000), 4000 - STRPOS(REVERSE(LEFT(X.ids, 4000)), ',') + 1), '...')
    ELSE X.ids
  END AS IDENTIFIERS
FROM (
  SELECT
    LISTAGG(successorsIdentifier, ', ') AS ids,
    (
      SELECT
        record_id
      FROM spatial_reporting.RiverBasinDistrict
      LIMIT 1
    ) AS record_id
  FROM spatial_reporting.RiverBasinDistrict
  WHERE
    (
      COALESCE(successorsIdentifier, '') <> ''
      OR COALESCE(successorsIdentifierScheme, '') <> ''
    )
  HAVING
    COUNT(*) > 0
) AS X