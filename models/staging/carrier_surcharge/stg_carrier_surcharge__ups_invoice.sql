with 

source as (

    select * from {{ source('carrier_surcharge', 'ups_invoice') }} 

),

timefilt as (

    select *
    from source
    where Invoice_Date >= '2025-10-16'

),

renamed as (

    select
        Invoice_Date as Invoice_Date,
     -- Custom rule: Dec 28 2025 – Jan 2 2026 → week52 of 2025
        case
            when Invoice_Date between '2025-12-28' and '2026-01-03'
                then 'week52'
            else concat('week', cast(extract(week from Invoice_Date) as string))
        end as invoice_week,

        -- Custom rule: Dec 28 2025 – Jan 2 2026 → year 2025
        case
            when Invoice_Date between '2025-12-28' and '2026-01-03'
                then '2025'
            else cast(extract(year from Invoice_Date) as string)
        end as invoice_year,
        Charge_Description_Code as charge_description_code,
        Net_Amount as net_amount

    from timefilt

)

select * from renamed