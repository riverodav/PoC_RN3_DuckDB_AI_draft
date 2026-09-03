WITH vProtectedArea AS (
  SELECT
    record_id,
    thematicIdIdentifier,
    CASE WHEN geometry_polygon <> CAST('' AS BLOB) THEN geometry_polygon ELSE NULL END AS geometry_any
  FROM spatial_reporting.RiverBasinDistrict
), vDimensionOriginal AS (
  SELECT
    record_id,
    thematicIdIdentifier,
    geometry_any,
    CASE
      WHEN ST_AREA(geometry_any) > 0
      THEN 2
      WHEN ST_LENGTH(geometry_any) > 0 AND ST_AREA(geometry_any) = 0
      THEN 1
      WHEN ST_LENGTH(geometry_any) = 0
      THEN 0
      ELSE -1
    END AS geometry_dim
  FROM vProtectedArea
  WHERE
    NOT geometry_any IS NULL
), vReportedZone_MakeValidGeometry AS (
  SELECT
    record_id,
    thematicIdIdentifier,
    ST_MAKEVALID(geometry_any) AS geometry_any,
    geometry_dim
  FROM vDimensionOriginal
  WHERE
    NOT geometry_any IS NULL
), vDimensionMakeValid AS (
  SELECT
    record_id,
    thematicIdIdentifier,
    geometry_any,
    geometry_dim,
    CASE
      WHEN ST_AREA(geometry_any) > 0
      THEN 2
      WHEN ST_LENGTH(geometry_any) > 0 AND ST_AREA(geometry_any) = 0
      THEN 1
      WHEN ST_LENGTH(geometry_any) = 0
      THEN 0
      ELSE -1
    END AS geometry_dimMakeValid
  FROM vReportedZone_MakeValidGeometry
  WHERE
    NOT geometry_any IS NULL
), vReportedZone_IsValidGeometry AS (
  SELECT
    record_id,
    geometry_any
  FROM vDimensionMakeValid
  WHERE
    ST_ISVALID(geometry_any)
    AND NOT ST_ISEMPTY(geometry_any)
    AND geometry_dimMakeValid = geometry_dim
), vSRIDs /* We calculate SRID of valid geometries */ AS (
  SELECT
    record_id,
    ST_SRID(geometry_any) AS srid
  FROM vReportedZone_IsValidGeometry
), vSRIDs /* We grouped by srid to see if there are more than one */ AS (
  SELECT
    record_id,
    ST_SRID(geometry_any) AS srid
  FROM vReportedZone_IsValidGeometry
)
SELECT
  LISTAGG(
    DISTINCT CASE WHEN srid IS NULL THEN NULL WHEN ', ' IS NULL THEN NULL ELSE (srid, ', ') END
  ) AS srid_list,
  MIN(record_id) AS record_id
FROM vSRIDs
HAVING
  COUNT(DISTINCT srid) > 1