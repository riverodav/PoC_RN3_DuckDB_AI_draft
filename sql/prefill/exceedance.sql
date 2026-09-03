-- prefill view: exceedance (descriptive, DWD)
-- Parameterised by the session variables country_code and cycle_year.
-- TODO: confirm the Azure Parquet path and hive-partition columns for this dataflow.
SELECT *
    , stable_record_id('exceedance|' || COALESCE(countryCode, '') || '|' || COALESCE("exceedanceidentifier", '')) AS record_id
FROM read_parquet('az://dis2datalake.blob.core.windows.net/test/test/exceedance/*/*/*.parquet', hive_partitioning = true)
WHERE CAST(cYear AS VARCHAR) = getvariable('cycle_year')
  AND countryCode = getvariable('country_code')
