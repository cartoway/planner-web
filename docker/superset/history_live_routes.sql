drop view if exists history_live_routes;
create view history_live_routes as
with
routes_c as (
    select
        routes.*,
        count(stops.id) as stop_count,
        count(stops.id) filter (where stops.out_of_window) as out_of_window_count,
        array_agg(stops.loads) as agg_loads
    from
        routes
        join stops on
            stops.route_id = routes.id
    group by
        routes.id
),
routes_d as (
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
a as (
    select
        plannings.customer_id,
        plannings.id as planning_id,
        r.key::integer,
        count(*) as count
    from
        plannings
        JOIN routes on
            routes.planning_id = plannings.id
        join lateral jsonb_each_text(pickups::jsonb || deliveries::jsonb) as r(key, value) on true
        join deliverable_units on
            deliverable_units.id = r.key::integer
    where
        r.value::float != 0
    group by
        plannings.customer_id,
        plannings.id,
        r.key
),
b as (
    select
        a.customer_id,
        planning_id,
        key,
        deliverable_units.label,
        ROW_NUMBER() OVER (PARTITION BY planning_id ORDER BY count DESC) as rank
    from
        a
        join deliverable_units on
            deliverable_units.customer_id = a.customer_id and
            deliverable_units.id = a.key
),
c as (
    select
        customer_id,
        planning_id,
        (array_agg(key))[1] as key1,
        (array_agg(label))[1] as label1,
        (array_agg(key))[2] as key2,
        (array_agg(label))[2] as label2,
        (array_agg(key))[3] as key3,
        (array_agg(label))[3] as label3
    from
        b
    where
        rank <= 3
    group by
        customer_id,
        planning_id
),
routes_a as (
    select
        plannings.customer_id,
        plannings.name AS planning_name,
        plannings.ref AS planning_ref,
        plannings.date AS planning_date,
        routes.*,
        vehicles.id as vehicle_id,
        vehicles.name as vehicle_name,
        vehicles.capacities as vehicle_capacities
    from
        plannings
        join routes_d as routes on
            routes.planning_id = plannings.id
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

    routes.distance / 1000 as distance,
    routes.emission as emission,

    (routes.end - routes.start)::float * 1000 as duration,
    routes.drive_time::float * 1000 as drive_time,
    routes.wait_time::float * 1000 as wait_time,
    routes.visits_duration::float * 1000 as visits_duration,

    routes.revenue as revenue,
    routes.cost_distance + routes.cost_fixed + routes.cost_time as cost,
    routes.revenue - routes.cost_distance - routes.cost_fixed - routes.cost_time as profit,

    c.label1 as label_pickups1,
    (routes.pickups-> (c.key1::text))::float as pickups1,
    (routes.deliveries-> (c.key1::text))::float as deliveries1,
    (routes.max_loads-> (c.key1::text))::float as max_loads1,
    nullif(coalesce(routes.vehicle_capacities->> (c.key1::text), '0')::float, 0) as capa1,

    c.label2 as label_pickups2,
    (routes.pickups-> (c.key2::text))::float as pickups2,
    (routes.deliveries-> (c.key2::text))::float as deliveries2,
    (routes.max_loads-> (c.key2::text))::float as max_loads2,
    nullif(coalesce(routes.vehicle_capacities->> (c.key2::text), '0')::float, 0) as capa2,

    c.label3 as label_pickups3,
    (routes.pickups-> (c.key3::text))::float as pickups3,
    (routes.deliveries-> (c.key3::text))::float as deliveries3,
    (routes.max_loads-> (c.key3::text))::float as max_loads3,
    nullif(coalesce(routes.vehicle_capacities->> (c.key3::text), '0')::float, 0) as capa3,

    routes.stop_out_of_work_time,
    stop_count,
    out_of_window_count
from
    routes_a as routes
    left join c on
        routes.customer_id = c.customer_id and
        routes.planning_id = c.planning_id
;
