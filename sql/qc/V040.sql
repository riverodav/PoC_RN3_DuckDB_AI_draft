WITH Data AS (
  SELECT
    record_id,
    predecessorsIdentifier,
    '^' || getvariable('country_code') || '[0-9A-Z]{1}(([0-9A-Z]|\-(?![\-_])|_(?![\-_])){0,38}[0-9A-Z]{1}){0,1}(, ?' || getvariable('country_code') || '[0-9A-Z]{1}(([0-9A-Z]|\-(?![\-_])|_(?![\-_])){0,38}[0-9A-Z]{1}){0,1})*$' AS regexp
  FROM spatial_reporting.RiverBasinDistrict
  WHERE
    COALESCE(predecessorsIdentifier, '') <> ''
)
SELECT
  record_id,
  predecessorsIdentifier
FROM Data
WHERE
  NOT regexp_matches(predecessorsIdentifier, regexp)
