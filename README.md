# carrier_surcharge

Description
-----------
Invoices comparison for surcharge check

Table of contents
-----------------
- Overview
- From legacy to analytics engineering (why this project matters)
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

From legacy to analytics engineering (why this project matters)
----------------------------------------------------------------
This repository documents and implements the migration from legacy, ad-hoc invoice analyses to a reproducible analytics engineering workflow. Key improvements delivered by this project:

- Standardized inputs: raw tables are defined as dbt sources with freshness metadata, ensuring reliable and auditable ingestion.
- Repeatable transformations: dbt staging models de-duplicate, normalize, and document business logic (week handling, mappings) so analyses are consistent.
- Tested data contracts: dbt schema tests (not_null, unique, accepted_values) enforce data quality at model boundaries.
- Versioned business logic: SQL and docs live in git, making changes reviewable and traceable instead of buried in spreadsheets.
- Automated CI: example GitHub Actions workflow runs dbt deps/run/test on pushes/PRs to catch regressions early.
- Lineage & documentation: model docs and YAML make it easy for analysts and engineers to understand column meanings and accepted values.
- Reconciliation-first design: explicit checks and reconciliation models compare predicted spend vs invoiced amounts and handle known invoice lag (3 weeks for residential).

These changes reduce manual effort, increase confidence in results, and enable faster iteration on business rules.

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
- invoice_date
- invoice_week (custom week label derived in staging)
- invoice_year (derived in staging)
- charge_description_code
- net_amount

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

Getting started (example dbt profile)
-------------------------------------
Below is a sample BigQuery profile for dbt (profiles.yml). Replace project/dataset/keys with your environment values.

```yaml
carrier_surcharge:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: service-account
      project: your-gcp-project-id
      dataset: analytics_dataset
      keyfile: /path/to/service-account.json
      timeout_seconds: 300
      location: US
```

Example mart and tests (models/marts/reconciliation)
----------------------------------------------------
Create a mart that performs the weekly reconciliation between predicted spend and invoice pivot. Example file: models/marts/reconciliation/mart_weekly_reconciliation.sql

```sql
with invoice_pivot as (
  select
    invoice_year,
    invoice_week,
    charge_description_code,
    sum(net_amount) as invoice_surcharge_amt
  from {{ ref('stg_carrier_surcharge__ups_invoice') }}
  group by 1,2,3
),

predicted as (
  -- placeholder: aggregate est_volume from shipping history and join price table
  select
    '2025' as invoice_year,
    'week1' as invoice_week,
    'Ground Residential' as charge_description_code,
    1000.0 as predicted_spend
)

select
  p.invoice_year,
  p.invoice_week,
  p.charge_description_code,
  p.predicted_spend,
  i.invoice_surcharge_amt,
  abs(p.predicted_spend - i.invoice_surcharge_amt) as absolute_diff,
  case when i.invoice_surcharge_amt = 0 then null else abs(p.predicted_spend - i.invoice_surcharge_amt)/i.invoice_surcharge_amt end as pct_diff
from predicted p
left join invoice_pivot i
  on i.invoice_year = p.invoice_year
  and i.invoice_week = p.invoice_week
  and i.charge_description_code = p.charge_description_code
```

Example mart schema (models/marts/reconciliation/schema.yml)
```yaml
version: 2
models:
  - name: mart_weekly_reconciliation
    description: "Weekly comparison of predicted spend vs UPS invoice pivot"
    tests:
      - dbt_utils.expression_is_true:
          expression: "pct_diff is null or pct_diff < 0.2"  # example tolerance (20%)
```

CI: GitHub Actions example (.github/workflows/dbt-ci.yml)
--------------------------------------------------------
This workflow runs dbt deps, dbt run, and dbt test on pushes to main and on PRs. It uses secrets for GCP service account key (BASE64 encoded) and the BigQuery project/dataset.

```yaml
name: dbt CI
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  dbt:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install dbt-core dbt-bigquery dbt-utils
      - name: Decode GCP key
        env:
          DBT_GCP_KEY_BASE64: ${{ secrets.DBT_GCP_KEY_BASE64 }}
        run: |
          echo "$DBT_GCP_KEY_BASE64" | base64 --decode > ./gcp_key.json
      - name: Run dbt
        env:
          GOOGLE_APPLICATION_CREDENTIALS: ./gcp_key.json
        run: |
          dbt --version
          dbt deps
          dbt run --select stg_carrier_surcharge__*
          dbt test --select stg_carrier_surcharge__*
```

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
