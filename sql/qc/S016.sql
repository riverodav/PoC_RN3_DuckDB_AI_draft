/*
    S016 - River Basin Districts must not overlap each other by more than 625 m2.
    Adapted from transpile_qcs/translated_qcs/S016.sql for the local DuckDB runtime:
      - the GeoPackage layer exposes the geometry as `geom` already typed GEOMETRY (EPSG:3035),
        so the empty-BLOB comparisons and the ST_Transform() call of the RN3 version are dropped;
      - `{%R3_COUNTRY_CODE%}` is not needed, the exported layer only holds one country.
*/
WITH ValuesToCompare AS ( /* reported geometries that are usable polygons */
  SELECT
    record_id,
    thematicIdIdentifier,
    ST_MakeValid(geom) AS geometry_3035
  FROM spatial_reporting.RiverBasinDistrict
  WHERE
    geom IS NOT NULL
    AND ST_IsEmpty(geom) IS FALSE
    AND ST_IsValid(geom) IS TRUE
    AND ST_Area(geom) > 0 /* it is a polygon; ST_Dimension is not available */
), PairsToCompare AS ( /* cartesian product excluding self and commutative comparisons */
  SELECT
    G1.record_id AS record_id1,
    G1.thematicIdIdentifier AS thematicIdIdentifier1,
    G1.geometry_3035 AS geometry_polygon1,
    G2.thematicIdIdentifier AS thematicIdIdentifier2,
    G2.geometry_3035 AS geometry_polygon2
  FROM ValuesToCompare AS G1
  JOIN ValuesToCompare AS G2
    ON G2.thematicIdIdentifier > G1.thematicIdIdentifier
), Overlapping AS (
  SELECT
    record_id1 AS record_id,
    thematicIdIdentifier1 AS thematicIdIdentifier,
    LISTAGG(thematicIdIdentifier2, ', ') AS overlapsWith
  FROM PairsToCompare
  WHERE
    ST_Area(ST_Intersection(geometry_polygon1, geometry_polygon2)) >= CAST(625 AS DOUBLE) /* 625 square metres */
  GROUP BY
    record_id1,
    thematicIdIdentifier1
)
SELECT
  record_id,
  thematicIdIdentifier,
  CASE
    WHEN LENGTH(overlapsWith) > 4000
    THEN CONCAT(
      LEFT(LEFT(overlapsWith, 4000), 4000 - STRPOS(REVERSE(LEFT(overlapsWith, 4000)), ',') + 1),
      '...'
    )
    ELSE overlapsWith
  END AS overlapsWith
FROM Overlapping
