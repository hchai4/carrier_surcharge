select *
from {{ ref('stg_carrier_surcharge__shipping_history') }}
where tracking_number != trim(tracking_number)
   or tracking_number = ''
