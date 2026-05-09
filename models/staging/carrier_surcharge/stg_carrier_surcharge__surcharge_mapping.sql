with 

source as (

    select * from {{ source('carrier_surcharge', 'surcharge_mapping') }}

),

renamed as (

    select
        Charge_Description as charge_description,
        Charge_Code as charge_code

    from source

)

select * from renamed