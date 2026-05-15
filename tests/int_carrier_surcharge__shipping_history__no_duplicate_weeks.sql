with duplicate_weeks as (
    select
        create_year,
        create_week,
        count(*) as row_count
    from {{ ref('int_carrier_surcharge__shipping_history') }}
    group by 1, 2
    having count(*) > 1
)

select *
from duplicate_weeks
