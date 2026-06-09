with raw_hosts as(
select * from AIRBNB.RAW.RAW_HOSTS
)

SELECT
    id AS host_id,
    name as host_name,
    is_superhost,
    created_at,
    updated_at
    
FROM
    raw_hosts