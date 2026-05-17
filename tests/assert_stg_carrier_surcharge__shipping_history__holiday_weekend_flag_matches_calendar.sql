with base as (
    select *
    from {{ ref('stg_carrier_surcharge__shipping_history') }}
),

validation_errors as (
    select *
    from base
    where is_holiday_weekend != (
        create_date in (
            '2025-11-29', '2025-11-30',
            '2025-12-27', '2025-12-28',
            '2026-01-03', '2026-01-04'
        )
    )
)

select *
from validation_errors
