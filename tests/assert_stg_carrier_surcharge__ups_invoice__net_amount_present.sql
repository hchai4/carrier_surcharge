select *
from {{ ref('stg_carrier_surcharge__ups_invoice') }}
where net_amount is null
