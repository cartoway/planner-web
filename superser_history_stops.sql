with stops as (
select
    customer_id,
    date_trunc('day', date)::timestamp as date,
    vehicle->>'name' AS vehicule_name,
    -- stop->'stop' as stop,
    stop->'stop'->>'status' as status,
    EXTRACT(epoch FROM (stop->'stop'->>'status_updated_at')::timestamp) as status_updated_at,
    -- stop->'visit' as visit,
    EXTRACT(epoch FROM date_trunc('day', date)) + ((stop->'visit'->>'time_window_end_1')::integer) as time_window_end_1,
    EXTRACT(epoch FROM date_trunc('day', date)) + ((stop->'visit'->>'time_window_end_2')::integer) as time_window_end_2,
    EXTRACT(epoch FROM date_trunc('day', date)) + ((stop->'visit'->>'time_window_start_1')::integer) as time_window_start_1,
    EXTRACT(epoch FROM date_trunc('day', date)) + ((stop->'visit'->>'time_window_start_2')::integer) as time_window_start_2,

    stop->'destination' as destination
from
    history_stops
    join lateral jsonb_array_elements(stops) as stop on true
where
    stops_active_count > 0
)
select
    status_updated_at,
    time_window_end_1,
    time_window_end_2,
    time_window_start_1,
    time_window_start_2,
    CASE
    WHEN status_updated_at is NULL then Null
    when
        ((time_window_start_1 IS NULL or status_updated_at >= time_window_start_1) and
            (time_window_end_1 IS NULL or status_updated_at <= time_window_end_1)) or
        ((time_window_start_2 IS NULL or status_updated_at >= time_window_start_2) and
            (time_window_end_2 IS NULL or status_updated_at <= time_window_end_2))
    then 0
    else
        least(
            abs(status_updated_at - time_window_start_1),
            abs(status_updated_at - time_window_end_1),
            abs(status_updated_at - time_window_start_2),
            abs(status_updated_at - time_window_end_2)
        )
    end
from
    stops
;
