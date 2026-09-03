-- export: SPATIAL_RiverBasinDistrict -> OGC GeoPackage
-- {{output_path}} is substituted at run time: COPY targets must be string literals,
-- which is also why export statements cannot be stored as views.
COPY (
    SELECT * EXCLUDE (geometry_polygon)
        , geometry_polygon
    FROM prefill.SPATIAL_RiverBasinDistrict
) TO '{{output_path}}' WITH (
    FORMAT gdal,
    DRIVER 'GPKG',
    SRS 'EPSG:3035',
    LAYER_NAME 'RiverBasinDistrict',
    LAYER_CREATION_OPTIONS 'GEOMETRY_NAME=geom'
);
