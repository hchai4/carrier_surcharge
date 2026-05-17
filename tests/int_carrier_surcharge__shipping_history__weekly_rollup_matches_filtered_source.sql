with expected as (
    select
        create_year,
        create_week,
        countif(service_type = '038-UPS Ground' and address_type = 'R') as expected_ground_resi,
        countif(service_type = '038-UPS Ground' and address_type = 'C') as expected_ground_comm,
        countif(service_type in (
            '040-UPS Next Day saver-UPS Next Day Air',
            '055-UPS Next Day Air-UPS Next Day Air'
        ) and address_type = 'R') as expected_next_day_resi,
        countif(service_type in (
            '040-UPS Next Day saver-UPS Next Day Air',
            '055-UPS Next Day Air-UPS Next Day Air'
        ) and address_type = 'C') as expected_next_day_comm,
        countif(service_type in (
            '014-UPS 3 days-UPS Other Express',
            '039-UPS 2nd Day-UPS Other Express'
        ) and address_type = 'R') as expected_other_express_resi,
        countif(service_type in (
            '014-UPS 3 days-UPS Other Express',
            '039-UPS 2nd Day-UPS Other Express'
        ) and address_type = 'C') as expected_other_express_comm,
        count(tracking_number) as expected_total_count
    from {{ ref('stg_carrier_surcharge__shipping_history') }}
    where warehouse_number in ('09', '16')
      and status = 'Y'
      and shipping_carrier_type = 'UPS'
    group by 1, 2
),

actual as (
    select *
    from {{ ref('int_carrier_surcharge__shipping_history') }}
),

validation_errors as (
    select
        actual.*,
        expected.expected_ground_resi,
        expected.expected_ground_comm,
        expected.expected_next_day_resi,
        expected.expected_next_day_comm,
        expected.expected_other_express_resi,
        expected.expected_other_express_comm,
        expected.expected_total_count
    from actual
    inner join expected
        on actual.create_year = expected.create_year
       and actual.create_week = expected.create_week
    where actual.Ground_Resi != expected.expected_ground_resi
       or actual.Ground_Comm != expected.expected_ground_comm
       or actual.Next_Day_Resi != expected.expected_next_day_resi
       or actual.Next_Day_Comm != expected.expected_next_day_comm
       or actual.Other_Express_Resi != expected.expected_other_express_resi
       or actual.Other_Express_Comm != expected.expected_other_express_comm
       or actual.total_count != expected.expected_total_count
)

select *
from validation_errors
