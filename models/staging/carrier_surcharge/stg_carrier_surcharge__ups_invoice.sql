with 

source as (

    select * from {{ source('carrier_surcharge', 'ups_invoice') }}

),

renamed as (

    select
        Invoice_Date as invoice_date,
        concat('week', cast(extract(week from Invoice_Date) as string)) as invoice_week,
        cast(extract(year from Invoice_Date) as string) as invoice_year,
        Charge_Description_Code as charge_description_code,
        Net_Amount as net_amount

    from source

)

select * from renamed