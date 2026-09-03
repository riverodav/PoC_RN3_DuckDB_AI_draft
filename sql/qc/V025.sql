SELECT
  record_id,
  nameTextInternational
FROM spatial_reporting.RiverBasinDistrict
WHERE
  COALESCE(nameTextInternational, '') <> ''
  AND NOT REGEXP_MATCHES(nameTextInternational, '^[A-Z0-9](?:[A-Z0-9]+(?:[- ][A-Z0-9]+)*)?$')