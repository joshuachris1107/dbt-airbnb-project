with raw_hosts as(
select * from AIRBNB.raw.raw_hosts
)

SELECT
    id AS host_id,
    name as host_name,
    is_superhost,
    created_at,
    updated_at
    
FROM
    raw_hosts