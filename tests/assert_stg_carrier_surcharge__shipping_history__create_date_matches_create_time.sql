select *
from {{ ref('stg_carrier_surcharge__shipping_history') }}
where create_date != date(create_time)
