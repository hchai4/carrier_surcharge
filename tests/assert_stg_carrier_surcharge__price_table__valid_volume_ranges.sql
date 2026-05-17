select *
from {{ ref('stg_carrier_surcharge__price_table') }}
where volume_min is null
   or volume_max is null
   or volume_min > volume_max
