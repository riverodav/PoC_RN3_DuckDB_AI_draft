SELECT
  record_id,
  ST_ISVALIDREASON(geometry_polygon) AS reason
FROM spatial_reporting.RiverBasinDistrict
WHERE
  geometry_polygon <> CAST('' AS BLOB)
  AND NOT ST_ISSIMPLE(ST_MAKEVALID(geometry_polygon))