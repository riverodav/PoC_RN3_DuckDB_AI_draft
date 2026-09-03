-- prefill view: parameter (descriptive, DWD — from dataset_61669)
-- This is the country-submitted parametric values catalogue, not a global reference table.
-- Parameterised by the session variables country_code and cycle_year.
-- TODO: confirm the Azure Parquet path and hive-partition columns for this dataflow.
SELECT *
    , stable_record_id('parameter|' || COALESCE(countryCode, '') || '|' || COALESCE("notation", '')) AS record_id
FROM read_parquet('az://dis2datalake.blob.core.windows.net/test/test/parameter/*/*/*.parquet', hive_partitioning = true)
WHERE CAST(cYear AS VARCHAR) = getvariable('cycle_year')
  AND countryCode = getvariable('country_code')
