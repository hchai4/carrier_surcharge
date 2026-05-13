-- models/intermediate/int_carrier_surcharge__shipping_weekly_counts.sql

with source as (

    select * from {{ ref('stg_carrier_surcharge__shipping_history') }}

),

filtered as (

    select *
    from source
    where
        warehouse_number in ('09', '16')
        and status = 'Y'
        and shipping_carrier_type = 'UPS'

),

weekly_counts as (

    select
        create_year,
        create_week,

        -- 1. Ground Residential
        countif(
            service_type = '038-UPS Ground'
            and address_type = 'R'
        ) as Ground_Resi,

        -- 2. Ground Commercial
        countif(
            service_type = '038-UPS Ground'
            and address_type = 'C'
        ) as Ground_Comm,

        -- 3. Next Day Residential
        countif(
            service_type in (
                '040-UPS Next Day saver-UPS Next Day Air',
                '055-UPS Next Day Air-UPS Next Day Air'
            )
            and address_type = 'R'
        ) as Next_Day_Resi,

        -- 4. Next Day Commercial
        countif(
            service_type in (
                '040-UPS Next Day saver-UPS Next Day Air',
                '055-UPS Next Day Air-UPS Next Day Air'
            )
            and address_type = 'C'
        ) as Next_Day_Comm,

        -- 5. Other Express Residential
        countif(
            service_type in (
                '014-UPS 3 days-UPS Other Express',
                '039-UPS 2nd Day-UPS Other Express'
            )
            and address_type = 'R'
        ) as Other_Express_Resi,

        -- 6. Other Express Commercial
        countif(
            service_type in (
                '014-UPS 3 days-UPS Other Express',
                '039-UPS 2nd Day-UPS Other Express'
            )
            and address_type = 'C'
        ) as Other_Express_Comm,

        -- Total across all categories
        count(tracking_number) as total_count

    from filtered
    group by create_year, create_week

)

select * from weekly_counts