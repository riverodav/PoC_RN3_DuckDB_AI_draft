WITH Data AS (
  SELECT
    record_id,
    thematicIdIdentifier,
    '^' || getvariable('country_code') || '[0-9A-Z]{1}(([0-9A-Z]|\-(?![\-_])|_(?![\-_])){0,38}[0-9A-Z]{1}){0,1}$' AS regexp
  FROM spatial_reporting.RiverBasinDistrict
  WHERE
    COALESCE(thematicIdIdentifier, '') <> ''
)
SELECT
  record_id,
  thematicIdIdentifier
FROM Data
WHERE
  NOT regexp_matches(thematicIdIdentifier, regexp)
