with base as (
    select *
    from {{ ref('stg_carrier_surcharge__ups_invoice') }}
),

validation_errors as (
    select *
    from base
    where (
        invoice_date between '2025-12-28' and '2026-01-03'
        and (invoice_week != 'week52' or invoice_year != '2025')
    )
    or (
        invoice_date not between '2025-12-28' and '2026-01-03'
        and (
            invoice_week != concat('week', cast(extract(week from invoice_date) as string))
            or invoice_year != cast(extract(year from invoice_date) as string)
        )
    )
)

select *
from validation_errors
