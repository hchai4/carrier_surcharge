with source as (

    select * from {{ source('carrier_surcharge', 'price_table') }}

)

select * from source
