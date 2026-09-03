SELECT
  record_id,
  ST_SRID(geometry_polygon) AS srid
FROM spatial_reporting.RiverBasinDistrict
WHERE
  geometry_polygon <> CAST('' AS BLOB)
  AND NOT ST_SRID(geometry_polygon) IN (4326, 4258, 3035)