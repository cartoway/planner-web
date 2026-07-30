drop view if exists history_live_routes cascade;
create view history_live_routes as
with
routes_c as (
    select
        routes.*,
        count(stops.id) as stop_count,
        count(stops.id) filter (where stops.type = 'StopVisit') as stop_visit_count,
        count(stops.id) filter (where stops.type = 'StopStore') as stop_store_count,
        count(stops.id) filter (where stops.out_of_window) as out_of_window_count,
        array_agg(stops.loads order by stops.index) as agg_loads
    from
        routes
        join stops on
            stops.route_id = routes.id
    group by
        routes.id
),
routes_d as (
    -- Recompute max_loads
    select
        routes.*,
        (
            select
                jsonb_object_agg(key, max_value)
            from
                unnest(routes.agg_loads) as t(loads),
                lateral (select key, max(value::float) as max_value from jsonb_each_text(loads) as r(key, value) where value::float > 0 group by key) as p
        ) as max_loads
    from
        routes_c as routes
),
routes_a as (
    select
        plannings.customer_id,
        plannings.name AS planning_name,
        plannings.ref AS planning_ref,
        plannings.date AS planning_date,
        routes.*,
        route_data.distance AS distance,
        route_data.emission AS emission,
        route_data.cost_distance AS cost_distance,
        route_data.cost_fixed AS cost_fixed,
        route_data.cost_time AS cost_time,
        route_data.revenue AS revenue,
        route_data.start AS start,
        route_data.end AS end,
        route_data.drive_time AS drive_time,
        route_data.wait_time AS wait_time,
        route_data.rests_duration AS rests_duration,
        route_data.visits_duration AS visits_duration,
        (select
            jsonb_object_agg(deliverable_units.label, value::float)
        from
            jsonb_each_text(route_data.pickups) as r(key, value)
            join deliverable_units on
                deliverable_units.customer_id = plannings.customer_id and
                deliverable_units.id = r.key::integer
        where deliverable_units.label is not null
        ) AS pickups,
        (select
            jsonb_object_agg(deliverable_units.label, value::float)
        from
            jsonb_each_text(route_data.deliveries) as r(key, value)
            join deliverable_units on
                deliverable_units.customer_id = plannings.customer_id and
                deliverable_units.id = r.key::integer
        where deliverable_units.label is not null
        ) AS deliveries,
        (select
            jsonb_object_agg(deliverable_units.label, value::float)
        from
            -- Recompute max_loads
            -- jsonb_each_text(route_data.max_loads) as r(key, value)
            jsonb_each_text(routes.max_loads) as r(key, value)
            join deliverable_units on
                deliverable_units.customer_id = plannings.customer_id and
                deliverable_units.id = r.key::integer
        where deliverable_units.label is not null
        ) AS max_loads_recomputed,
        vehicles.id as vehicle_id,
        vehicles.name as vehicle_name,
        (select
            jsonb_object_agg(deliverable_units.label, value::float)
        from
            jsonb_each_text(vehicles.capacities) as r(key, value)
            join deliverable_units on
                deliverable_units.customer_id = plannings.customer_id and
                deliverable_units.id = r.key::integer
        where deliverable_units.label is not null
        ) AS vehicle_capacities
    from
        plannings
        -- Recompute max_loads
        -- join routes_c as routes on
        join routes_d as routes on
            routes.planning_id = plannings.id
        join route_data on
            route_data.id = routes.route_data_id
        join vehicle_usages ON
            vehicle_usages.id = routes.vehicle_usage_id
        join vehicles ON
            vehicles.id = vehicle_usages.vehicle_id
)
select
    routes.customer_id,
    routes.planning_id,
    routes.planning_name,
    routes.planning_ref,
    routes.planning_date,
    routes.id as route_id,
    routes.ref as route_ref,
    routes.vehicle_usage_id,
    routes.vehicle_id,
    routes.vehicle_name,
    routes.vehicle_capacities,

    routes.distance / 1000 as distance,
    routes.emission as emission,

    (routes.end - routes.start)::float * 1000 as duration,
    routes.drive_time::float * 1000 as drive_time,
    routes.wait_time::float * 1000 as wait_time,
    routes.visits_duration::float * 1000 as visits_duration,
    routes.pickups,
    routes.deliveries,
    -- Recompute max_loads
    -- routes.max_loads,
    routes.max_loads_recomputed AS max_loads,
    (routes.end - routes.start - coalesce(routes.rests_duration, 0))::float * 1000 as work_duration,

    routes.revenue as revenue,
    routes.cost_distance + routes.cost_fixed + routes.cost_time as cost,
    routes.revenue - routes.cost_distance - routes.cost_fixed - routes.cost_time as profit,

    routes.stop_out_of_work_time,
    stop_count,
    stop_visit_count,
    stop_store_count,
    out_of_window_count
from
    routes_a as routes
;


drop view if exists history_live_routes_units cascade;
create view history_live_routes_units as
select
    *,
    (vehicle_capacities->>units_label)::float as vehicle_capacities_unit,
    (pickups->>units_label)::float as pickups_unit,
    (deliveries->>units_label)::float as deliveries_unit,
    (max_loads->>units_label)::float as max_loads_unit
from
    history_live_routes
    left join lateral (
        select '[None]'
        union all
        select jsonb_object_keys(vehicle_capacities)
    ) as units(units_label) on true
;
