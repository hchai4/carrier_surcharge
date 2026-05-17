select *
from {{ ref('stg_carrier_surcharge__ups_invoice') }}
where invoice_number is null
   or invoice_number = ''
   or invoice_number != trim(invoice_number)
