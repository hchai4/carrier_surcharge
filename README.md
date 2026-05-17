# carrier_surcharge

Description
-----------
Invoices comparison for surcharge check

Table of contents
-----------------
- Overview
- Data sources (raw)
- Staging models (dbt)
- Data model (modeled artifacts & columns)
- Transformation logic & SQL examples
- Validation & reconciliation checks
- File / directory layout (where models live)
- How to run (dbt)
- Tests & quality checks
- Contact

Overview
--------
This project reconciles UPS invoice surcharges against modeled DBS predictions (rates × estimated volumes), with special handling for peak-season codes and known invoice lags (UPS residential charges have a 3-week delay). The repo uses dbt-style staging models under models/staging/carrier_surcharge to standardize raw sources and prepare data for downstream comparison.

Data sources (raw)
------------------
These are the raw source tables as declared in the repository:
- Source group: carrier_surcharge
  - database: carrier-surcharge
  - schema: raw
  - tables:
    - surcharge_mapping
    - shipping_history
    - ups_invoice
    - price_table

Staging models (dbt)
--------------------
Staging models found in models/staging/carrier_surcharge:
- stg_carrier_surcharge__price_table (models/staging/carrier_surcharge/stg_carrier_surcharge__price_table.sql)
- stg_carrier_surcharge__shipping_history (models/staging/carrier_surcharge/stg_carrier_surcharge__shipping_history.sql)
- stg_carrier_surcharge__surcharge_mapping (models/staging/carrier_surcharge/stg_carrier_surcharge__surcharge_mapping.sql)
- stg_carrier_surcharge__ups_invoice (models/staging/carrier_surcharge/stg_carrier_surcharge__ups_invoice.sql)

Data model (modeled artifacts & suggested columns)
--------------------------------------------------

1) Raw sources (as named in the dbt sources)
- carrier-surcharge.raw.surcharge_mapping
  - Contains surcharge code mapping (Charge_Code, Charge_Description)
- carrier-surcharge.raw.shipping_history
  - Columns used by staging: TrackingNumber, ServiceType, AddressType, warehousenumber, status, ShippingCarrierType, CreateTime
- carrier-surcharge.raw.ups_invoice
  - Raw carrier invoice rows; primary key referenced in YAML: Invoice_Number
- carrier-surcharge.raw.price_table
  - UPS rate/pricing table per service_type and effective period

2) stg_carrier_surcharge__shipping_history (output columns; derived in SQL)
- service_type (from ServiceType)
- address_type (from AddressType; accepted values: R, C)
- tracking_number (trimmed TrackingNumber) — primary key in staging
- warehouse_number (from warehousenumber)
- status (converted to 'Y'/'N' in staging)
- shipping_carrier_type (accepted values: UPS, Fedex, USPS)
- create_time (raw CreateTime timestamp)
- create_date (date(create_time))
- create_week (custom week label; special handling for 2025-12-28..2026-01-03 mapped to 'week52')
- create_year (year or special-case '2025')
- is_holiday_weekend (boolean flag for certain date ranges)

Notes from the shipping_history transformation:
- The model de-duplicates by TrackingNumber selecting the latest CreateTime:
  - qualify row_number() over (partition by TrackingNumber order by CreateTime desc) = 1
- The model validates presence of required fields and filters to date range:
  - date(create_time) >= '2025-10-26' and date(create_time) < '2026-01-17'

3) stg_carrier_surcharge__surcharge_mapping (output columns)
- charge_description (mapped from Charge_Description)
- charge_code (mapped from Charge_Code)

4) stg_carrier_surcharge__price_table (pass-through)
- The price table staging model currently selects all from the source:
  - select * from {{ source('carrier_surcharge', 'price_table') }}
- service_type values accepted in YAML/docs:
  - Ground Residential
  - Next Day Air Residential
  - Next Day Air Commercial
  - Other Express Residential
  - Other Express Commercial

5) stg_carrier_surcharge__ups_invoice
- invoice_number (primary key in YAML)
- (Populate other invoice fields from the ups_invoice raw source; inspect stg file for full column mappings)

Transformation logic & SQL examples (extracted/derived from models)
------------------------------------------------------------------

1) Source usage pattern (found in staging SQLs)
Example:
```sql
with source as (
  select * from {{ source('carrier_surcharge', 'shipping_history') }}
)
select * from source
```

2) Shipping history dedup + rename (key snippets from stg_carrier_surcharge__shipping_history.sql)
- De-duplication:
```sql
qualify row_number() over (
  partition by TrackingNumber
  order by CreateTime desc
) = 1
```
- Rename & normalization:
```sql
nullif(trim(ServiceType), '')          as service_type,
nullif(trim(AddressType), '')          as address_type,
trim(TrackingNumber)                   as tracking_number,
nullif(trim(warehousenumber), '')      as warehouse_number,
case when status = true then 'Y' else 'N' end as status,
nullif(trim(ShippingCarrierType), '')  as shipping_carrier_type,
CreateTime                             as create_time,
date(CreateTime)                       as create_date,
-- custom week/year handling
```

3) Surcharge mapping normalization (key snippet)
```sql
select
  Charge_Description as charge_description,
  Charge_Code        as charge_code
from {{ source('carrier_surcharge', 'surcharge_mapping') }}
```

4) Example: building weekly pivot (use these fields from stg models)
Pseudo-SQL (to be adapted to your exact modeled column names in marts):
```sql
select
  invoice_year,
  invoice_week,
  account_number,
  sum(non_pri_amt) as total_non_pri_amt,
  sum(trackback_pri_amt) as total_trackback_pri_amt,
  sum(non_pri_amt) + sum(trackback_pri_amt) as pivot_surcharge_amt
from {{ ref('stg_carrier_surcharge__ups_invoice') }}
group by 1,2,3
```

5) Example: DBS predicted spend (concept)
- Aggregate estimated volume from stg_carrier_surcharge__shipping_history by week/service_type
- Join to stg_carrier_surcharge__price_table on service_type and effective date
- predicted_spend = est_volume * unit_rate

Lag handling
- UPS residential invoice charges are known to have ~3-week invoice delay.
- Align predicted week W with invoices from week W+3 when comparing residential charges (handle year boundaries carefully).

Validation & reconciliation checks
----------------------------------
- Source freshness: shipping_history and ups_invoice have freshness/load tracking configured in the source YAML.
- Dedup check: no duplicate tracking_number after stg_carrier_surcharge__shipping_history dedup.
- Null checks: staging YAML declares tests for primary keys (tracking_number, invoice_number).
- Pivot rule: pivot_surcharge_amt = total_non_pri_amt + total_trackback_pri_amt.
- Reconciliation metrics:
  - absolute_diff = |predicted_spend - invoice_surcharge_amt|
  - pct_diff = absolute_diff / nullif(invoice_surcharge_amt, 0)
  - Flag differences greater than configured thresholds (e.g., pct_diff > 10% or absolute > $1,000).
- Date-range validation: shipping history staging filters to date(create_time) between '2025-10-26' and '2026-01-17' (update as needed for future runs).

File / directory layout (key files discovered)
----------------------------------------------
- models/staging/carrier_surcharge/_src_carrier_surcharge.yml
- models/staging/carrier_surcharge/_stg_carrier_surcharge.yml
- models/staging/carrier_surcharge/carrier_surcharge_docs.md
- models/staging/carrier_surcharge/stg_carrier_surcharge__price_table.sql
- models/staging/carrier_surcharge/stg_carrier_surcharge__shipping_history.sql
- models/staging/carrier_surcharge/stg_carrier_surcharge__surcharge_mapping.sql
- models/staging/carrier_surcharge/stg_carrier_surcharge__ups_invoice.sql

How to run (dbt)
----------------
This project uses dbt-style models. Typical commands:
- Install dependencies (if required)
  - dbt deps
- Run staging models:
  - dbt run --select stg_carrier_surcharge__*
- Run tests declared in model YAML:
  - dbt test --select stg_carrier_surcharge__*
- Build specific models or the full project as appropriate:
  - dbt run
  - dbt test

Adapt these commands to your environment (dbt core, dbt Cloud, connection profiles).

Tests & data quality
--------------------
- YAML declares tests:
  - uniqueness and not_null on tracking_number and invoice_number
  - accepted_values for service_type, address_type, status, shipping_carrier_type
- Add reconciliation tests comparing predicted_spend vs invoice pivot (with invoice lag for residential)
- Add CI steps to run dbt tests and surface failures as alerts

Contact
-------
Repository owner / maintainer: hchai4
For questions, open an issue in the repository.

Appendix: quick pointers (what is present in the code)
------------------------------------------------------
- Sources are defined in models/staging/carrier_surcharge/_src_carrier_surcharge.yml and include freshness/load metadata.
- There are staging SQLs that:
  - pass through the price_table source
  - deduplicate and normalize shipping_history (including date-week logic and holiday/weekend flags)
  - normalize surcharge_mapping charge code/description
- YAML docs exist in carrier_surcharge_docs.md for service type and other enumerations.
