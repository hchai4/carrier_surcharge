with invoice as (

    select * from {{ ref('fct_carrier_surcharge__ups_invoice') }}

),

cost as (
    select * from {{ ref('fct_carrier_surcharge__weekly_cost') }}
),

abnormal as (
    select i.invoice_year,
           i.invoice_week,
           i.total_amount as invoice_amount,
           round(c.total_cost, 2) as projection_amount,
           i.total_amount - c.total_cost as diffrence,
           concat(round((i.total_amount - c.total_cost) / c.total_cost, 2)*100, '%') as diff_perct
    from invoice i join cost c on i.invoice_year = c.create_year and i.invoice_week = c.create_week
    where round((i.total_amount - c.total_cost) / c.total_cost, 2)*100 >= 1000
)

select * from abnormal