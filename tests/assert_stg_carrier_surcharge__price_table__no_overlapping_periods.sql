with base as (
    select *
    from {{ ref('stg_carrier_surcharge__price_table') }}
),

overlaps as (
    select
        a.service_type,
        a.tier_label,
        a.tier_threshold,
        a.volume_min,
        a.volume_max,
        a.period_start as left_period_start,
        a.period_end as left_period_end,
        b.period_start as right_period_start,
        b.period_end as right_period_end
    from base a
    join base b
        on a.service_type = b.service_type
       and a.tier_label = b.tier_label
       and a.tier_threshold = b.tier_threshold
       and a.volume_min = b.volume_min
       and a.volume_max = b.volume_max
       and a.period_start < b.period_start
       and a.period_end >= b.period_start
)

select *
from overlaps
