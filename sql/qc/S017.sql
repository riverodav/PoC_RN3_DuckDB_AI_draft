/* Note: thematicIdIdentifierScheme is ignored because only "euRBDCode" is used. */ /* It is important to guarantee the validity of geometries, namely: */ /*     They are not null. */ /*     They are not an empty string. */ /*     They are not an empty geometry. */ /*     The geometry is valid. */ /*     The geometry is a polygon (in which case its area is greater than zero). */ /*     Any created geometry must be made valid with ST_MakeValid() and checked. */
WITH GeometryRBD /* Gets all reported geometries that are valid and transform them as SRID 3035. */ AS (
  SELECT
    record_id,
    thematicIdIdentifier,
    ST_MAKEVALID(ST_TRANSFORM(geometry_polygon, 3035)) AS geometry_3035
  FROM spatial_reporting.RiverBasinDistrict
  WHERE
    geometry_polygon <> CAST('' AS BLOB)
    AND ST_ISEMPTY(geometry_polygon) IS FALSE
    AND ST_ISVALID(geometry_polygon) IS TRUE
    AND ST_AREA(geometry_polygon) > 0 /* It is a polygon. ST_Dimension is not available */
), ValuesToCompare /* Get transformed geometries that are valid. */ AS (
  SELECT
    record_id,
    thematicIdIdentifier,
    geometry_3035
  FROM GeometryRBD
  WHERE
    geometry_3035 <> CAST('' AS BLOB)
    AND ST_ISEMPTY(geometry_3035) IS FALSE
    AND ST_ISVALID(geometry_3035) IS TRUE
    AND ST_AREA(geometry_3035) > 0 /* It is a polygon. ST_Dimension is not available */
), PairsToCompare /* Cartesian product of RBDs excluding self and commutative comparisons. */ AS (
  SELECT
    G1.record_id AS record_id1,
    G1.thematicIdIdentifier AS thematicIdIdentifier1,
    G1.geometry_3035 AS geometry_polygon1,
    G2.record_id AS record_id2,
    G2.thematicIdIdentifier AS thematicIdIdentifier2,
    G2.geometry_3035 AS geometry_polygon2
  FROM ValuesToCompare AS G1
  JOIN ValuesToCompare AS G2
    ON G2.thematicIdIdentifier > G1.thematicIdIdentifier
), Overlapping /* Gets overlapping geometries */ AS (
  SELECT
    record_id1 AS record_id,
    thematicIdIdentifier1 AS thematicIdIdentifier,
    LISTAGG(thematicIdIdentifier2, ', ') AS overlapsWith
  FROM PairsToCompare
  WHERE
    ST_AREA(ST_INTERSECTION(geometry_polygon1, geometry_polygon2)) < CAST(625 AS DOUBLE) /* 625 square metres */
    AND ST_AREA(ST_INTERSECTION(geometry_polygon1, geometry_polygon2)) > 0
  GROUP BY
    record_id1,
    thematicIdIdentifier1
  HAVING
    COUNT(*) > 0
)
SELECT
  record_id,
  thematicIdIdentifier,
  CASE
    WHEN LENGTH(overlapsWith) > 4000
    THEN CONCAT(
      LEFT(
        LEFT(overlapsWith, 4000),
        4000 - STRPOS(REVERSE(LEFT(overlapsWith, 4000)), ',') + 1
      ),
      '...'
    )
    ELSE overlapsWith
  END AS overlapsWith
FROM Overlapping