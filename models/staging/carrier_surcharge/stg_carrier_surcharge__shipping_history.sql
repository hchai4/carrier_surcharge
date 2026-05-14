with source as (

    select * from {{ source('carrier_surcharge', 'shipping_history') }}

),

renamed as (

    select
        nullif(trim(ServiceType), '')          as service_type,
        nullif(trim(AddressType), '')          as address_type,
        trim(TrackingNumber)                   as tracking_number,
        nullif(trim(warehousenumber), '')      as warehouse_number,

        -- status is BOOLEAN in BQ (Y/N auto-detected as true/false)
        case when status = true then 'Y' else 'N' end as status,

        nullif(trim(ShippingCarrierType), '')  as shipping_carrier_type,
        CreateTime                             as create_time,
        date(CreateTime)                       as create_date,
        case
            when date(CreateTime) between '2025-12-28' and '2026-01-03'
                then 'week52'
            else concat('week', cast(extract(week from CreateTime) as string))
        end as create_week,
        case
            when date(CreateTime) between '2025-12-28' and '2026-01-03'
                then '2025'
            else cast(extract(year from CreateTime) as string)
        end as create_year,

        case when date(CreateTime) in (
            '2025-11-29', '2025-11-30',
            '2025-12-27', '2025-12-28',
            '2026-01-03', '2026-01-04'
        ) then true else false end             as is_holiday_weekend

    from source

),

validated as (

    select *
    from renamed
    where
        service_type is not null
        and address_type is not null
        and warehouse_number is not null
        and tracking_number is not null
        and status in ('Y', 'N')
        and shipping_carrier_type is not null
        and date(create_time) >= '2025-10-26'
        and date(create_time) <  '2026-01-17'

)

select * from validated