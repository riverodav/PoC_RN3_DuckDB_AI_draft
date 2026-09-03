WITH BothDates AS (
  SELECT
    record_id,
    CAST(beginLifespanVersion AS DATE) AS beginDate,
    CAST(endLifespanVersion AS DATE) AS endDate
  FROM spatial_reporting.RiverBasinDistrict
  /* Avoids values not reported */
  WHERE
    COALESCE(beginLifespanVersion, '') <> ''
    AND COALESCE(endLifespanVersion, '') <> ''
)
SELECT
  record_id,
  beginDate,
  endDate
FROM BothDates
WHERE
  NOT beginDate IS NULL AND NOT endDate IS NULL AND endDate <= beginDate