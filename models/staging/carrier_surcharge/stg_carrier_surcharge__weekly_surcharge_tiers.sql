with 

source as (

    select * from {{ source('carrier_surcharge', 'weekly_surcharge_tiers') }}

),

renamed as (

    select
        bill_to,
        process_dt,
        vol_week,
        plan,
        tier_from,
        tier_to,
        charge_per,
        vol_wgt,
        charge,
        service_level

    from source

)

select * from renamed