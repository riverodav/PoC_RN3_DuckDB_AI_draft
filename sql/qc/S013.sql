SELECT
  record_id
FROM spatial_reporting.RiverBasinDistrict
WHERE
  geometry_polygon <> CAST('' AS BLOB)
  AND (
    ST_ISVALID(geometry_polygon) /* It is not valid */ IS FALSE
    OR ST_ISEMPTY(geometry_polygon) /* It is not empty */ IS TRUE
    OR ST_AREA(geometry_polygon) /* It is not a polygon */ = 0
  )