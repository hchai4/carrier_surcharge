with counts as (

    select * from {{ ref('int_carrier_surcharge__shipping_history') }}

),

price as (

    select * from {{ ref('stg_carrier_surcharge__price_table') }}

),

-- Unpivot wide counts into long format for joining
unpivoted as (

    select create_year, create_week, week_start_date,
            'Ground Residential'    as service_type, 
           Ground_Resi    as package_count
    from counts
    union all
    select create_year, create_week, week_start_date,
           'Next Day Air Residential' as service_type, Next_Day_Resi as package_count
    from counts
    union all
    select create_year, create_week, week_start_date,
           'Next Day Air Commercial'  as service_type, Next_Day_Comm as package_count
    from counts
    union all
    select create_year, create_week, week_start_date,
           'Other Express Residential' as service_type, Other_Express_Resi as package_count
    from counts
    union all
    select create_year, create_week, week_start_date,
           'Other Express Commercial' as service_type, Other_Express_Comm as package_count
    from counts
    order by create_year, create_week, service_type

),

with_price as (

    select
        u.create_year,
        u.create_week,
        u.week_start_date,
        u.service_type,
        u.package_count,
        p.price_usd,
        p.tier_label,
        p.volume_min,
        p.volume_max,
        round(u.package_count * p.price_usd, 2) as total_cost_usd

    from unpivoted u
    left join price p
        on  u.service_type = p.service_type
        and u.week_start_date   between p.period_start and p.period_end
        and u.package_count     between p.volume_min   and p.volume_max
    order by create_year, create_week, service_type
),

weekly_cost as (
    select create_year,
           create_week,
           week_start_date,
           sum(total_cost_usd) as total_cost
    from with_price
    group by create_year, create_week, week_start_date
)

select * from weekly_cost
