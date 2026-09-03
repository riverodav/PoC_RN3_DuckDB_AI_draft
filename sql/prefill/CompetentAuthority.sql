-- prefill view: CompetentAuthority (descriptive)
-- Parameterised by the session variables country_code and cycle_year.
SELECT euCACode
    , competentAuthorityName
    , competentAuthorityNameNL
    , competentAuthorityNameNLLanguage
    , acronym
    , street
    , city
    , country
    , postCode
    , linkToCompetentAuthority AS url
    , stable_record_id('CompetentAuthority|' || countryCode || '|' || euCACode) AS record_id
FROM 'https://dis2datalake.blob.core.windows.net/discodata/wise_wfd/v2r1/rbdsuca_competentauthority.parquet'
WHERE CAST(cYear AS VARCHAR) = getvariable('cycle_year')
  AND countryCode = getvariable('country_code')
