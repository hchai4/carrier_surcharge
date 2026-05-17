with expected as (
    select
        create_year,
        create_week,
        min(create_date) as expected_week_start_date
    from {{ ref('stg_carrier_surcharge__shipping_history') }}
    where warehouse_number in ('09', '16')
      and status = 'Y'
      and shipping_carrier_type = 'UPS'
    group by 1, 2
),

actual as (
    select
        create_year,
        create_week,
        week_start_date
    from {{ ref('int_carrier_surcharge__shipping_history') }}
),

validation_errors as (
    select
        actual.create_year,
        actual.create_week,
        actual.week_start_date,
        expected.expected_week_start_date
    from actual
    inner join expected
        on actual.create_year = expected.create_year
       and actual.create_week = expected.create_week
    where actual.week_start_date != expected.expected_week_start_date
)

select *
from validation_errors
