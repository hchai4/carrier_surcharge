with duplicate_rows as (
    select
        period_start,
        period_end,
        service_type,
        tier_label,
        tier_threshold,
        volume_min,
        volume_max,
        count(*) as row_count
    from {{ ref('stg_carrier_surcharge__price_table') }}
    group by 1, 2, 3, 4, 5, 6, 7
    having count(*) > 1
)

select *
from duplicate_rows
