with source as (

    select * from {{ ref('stg_carrier_surcharge__ups_invoice') }}

),

-- Step 1: shift the reference date back 3 weeks for PRI rows
adjusted as (

    select
        invoice_number,
        case
            when charge_description_code = 'PRI'
                and date_sub(invoice_date, interval 3 week) >= '2025-10-26'
            then date_sub(invoice_date, interval 3 week)
            else invoice_date
        end as invoice_date,
        charge_description_code,
        net_amount

    from source
),

-- Step 2: extract week/year from the adjusted reference date
renamed as (

    select
        invoice_number,
        invoice_date,
        -- Business rule 1: Dec 28 – Jan 2 always = week52
        -- Business rule 2: PRI rows use date 3 weeks earlier
        case
            when invoice_date between '2025-12-28' and '2026-01-02'
                then 'week52'
            else concat('week', cast(extract(week from invoice_date) as string))
        end as invoice_week,

        case
            when invoice_date between '2025-12-28' and '2026-01-02'
                then '2025'
            else cast(extract(year from invoice_date) as string)
        end as invoice_year,
        Charge_Description_Code as charge_description_code,
        Net_Amount as net_amount

    from adjusted

),

-- Step 3 do amount summary for each week
summary as (

    select 
           invoice_year,
           invoice_week,
           round(sum(net_amount), 2) as total_amount
    from renamed
    group by invoice_year, invoice_week

)



select * from summary