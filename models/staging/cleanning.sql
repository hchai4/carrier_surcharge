-- models/staging/stg_shipping_history.sql

with source as (

    select * from {{ ref('_stg_carrier_surcharge__shipping_history') }}

),

renamed as (

    select

        -- ----------------------------------------------------------------
        -- a: ServiceType  (nullable)
        -- Domains: '014-UPS 3 days-...', '038-UPS Ground', '039-...', 
        --          '040-...', '055-...'
        -- ----------------------------------------------------------------
        nullif(trim("ServiceType"), '')          as service_type,

        -- ----------------------------------------------------------------
        -- b: AddressType  (nullable)
        -- Domains: 'R' (Residential), 'C' (Commercial)
        -- ----------------------------------------------------------------
        nullif(trim("AddressType"), '')          as address_type,

        -- ----------------------------------------------------------------
        -- c: TrackingNumber  (never null)
        -- Formats: 1Z + 16 alphanum | 20-digit numeric | 9-digit | 8-digit
        --          | LPH + 9 digits | NCU + 9 digits
        -- ----------------------------------------------------------------
        trim("TrackingNumber")                   as tracking_number,

        -- ----------------------------------------------------------------
        -- d: warehousenumber  (nullable)
        -- Domains: '09','16','36','04','AA213545','AA546456','00','95-04','9145-04'
        -- Skewed: '09' and '16' are dominant (~40% each)
        -- ----------------------------------------------------------------
        nullif(trim("warehousenumber"), '')       as warehouse_number,

        -- ----------------------------------------------------------------
        -- e: status  (never null)
        -- Domains: 'Y', 'N'
        -- ----------------------------------------------------------------
        trim("status")                           as status,

        -- ----------------------------------------------------------------
        -- f: ShippingCarrierType  (nullable)
        -- Domains: 'UPS', 'Fedex', 'USPS'
        -- ----------------------------------------------------------------
        nullif(trim("ShippingCarrierType"), '')  as shipping_carrier_type,

        -- ----------------------------------------------------------------
        -- g: CreateTime  (never null)
        -- Format: 'YYYY-MM-DD HH:MM:SS.000'
        -- Date range: 2025-10-01 to 2026-03-31
        -- Excludes non-holiday Saturdays; includes holiday Saturdays:
        --   Nov 29-30 (Black Friday weekend),
        --   Dec 27-28 (Christmas weekend),
        --   Jan 3-4   (New Year weekend)
        -- ----------------------------------------------------------------
        cast("CreateTime" as timestamp)          as create_time,

        -- Derived convenience columns
        cast("CreateTime" as date)               as create_date,
        date_trunc('week', cast("CreateTime" as date))  as create_week,
        date_trunc('month', cast("CreateTime" as date)) as create_month,

        -- Flag holiday weekends for downstream filtering / reporting
        case
            when cast("CreateTime" as date) in (
                '2025-11-29', '2025-11-30',
                '2025-12-27', '2025-12-28',
                '2026-01-03', '2026-01-04'
            ) then true
            else false
        end                                      as is_holiday_weekend

    from source

),

validated as (

    select *
    from renamed
    where
        -- c: tracking number must be present
        tracking_number is not null
        and tracking_number != ''

        -- e: status must be a known value
        and status in ('Y', 'N')

        -- g: create_time must be in the expected load window
        and create_time >= '2025-10-01'
        and create_time <  '2026-04-01'

)

select * from validated