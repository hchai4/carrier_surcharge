select *
from {{ ref('int_carrier_surcharge__shipping_history') }}
where coalesce(Ground_Resi, 0)
    + coalesce(Ground_Comm, 0)
    + coalesce(Next_Day_Resi, 0)
    + coalesce(Next_Day_Comm, 0)
    + coalesce(Other_Express_Resi, 0)
    + coalesce(Other_Express_Comm, 0) != total_count
