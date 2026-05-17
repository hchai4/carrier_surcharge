with base as (
    select *
    from {{ ref('stg_carrier_surcharge__shipping_history') }}
),

validation_errors as (
    select *
    from base
    where (
        create_date between '2025-12-28' and '2026-01-03'
        and (create_week != 'week52' or create_year != '2025')
    )
    or (
        create_date not between '2025-12-28' and '2026-01-03'
        and (
            create_week != concat('week', cast(extract(week from create_time) as string))
            or create_year != cast(extract(year from create_time) as string)
        )
    )
)

select *
from validation_errors
