-- export: SPATIAL_ProtectedArea -> OGC GeoPackage
-- {{output_path}} is substituted at run time: COPY targets must be string literals,
-- which is also why export statements cannot be stored as views.
-- polygon > point > line geometry priority collapses three columns into one geom.
COPY (
    SELECT thematicIdIdentifier
        , thematicIdIdentifierScheme
        , relatedzoneidentifier
        , relatedzoneidentifierscheme
        , record_id
        , CASE
            WHEN geometry_polygon IS NOT NULL THEN geometry_polygon
            WHEN geometry_point IS NOT NULL THEN geometry_point
            WHEN geometry_line IS NOT NULL THEN geometry_line
            ELSE NULL
          END AS geometry
    FROM prefill.SPATIAL_ProtectedArea
) TO '{{output_path}}' WITH (
    FORMAT gdal,
    DRIVER 'GPKG',
    SRS 'EPSG:3035',
    LAYER_NAME 'ProtectedArea',
    LAYER_CREATION_OPTIONS 'GEOMETRY_NAME=geom'
);
