select *
from {{ ref('stg_carrier_surcharge__ups_invoice') }}
where invoice_date < '2025-10-26'
   or invoice_date > '2026-01-17'
