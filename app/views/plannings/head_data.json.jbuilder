json.prefered_unit current_user.prefered_unit
json.prefered_currency current_user.prefered_currency
json.extract! @planning, :id, :ref
json.planning_id @planning.id

visible_for_stats = @planning.routes.available.includes_vehicle_usages.to_a
stats_routes = planning_statistics_routes(@planning, visible_for_stats, current_user)

duration = stats_routes.select(&:vehicle_usage).sum(0) { |route|
  route.visits_duration.to_i + route.wait_time.to_i + route.drive_time.to_i +
    route.vehicle_usage.default_service_time_start.to_i + route.vehicle_usage.default_service_time_end.to_i
}
json.duration time_over_day(duration)
json.distance locale_distance(stats_routes.sum(0) { |route| route.distance || 0 }, current_user.prefered_unit)
json.size stats_routes.sum(0) { |route| route.stops_size }
json.size_active stats_routes.sum(0) { |route| route.vehicle_usage_id ? route.size_active.to_i : 0 }

averages = @planning.averages(current_user.prefered_unit, routes: stats_routes)
if averages
  json.averages do
    json.routes_visits_duration time_over_day(averages[:routes_visits_duration].to_i)
    json.routes_rests_duration time_over_day(averages[:routes_rests_duration].to_i)
    json.routes_drive_time time_over_day(averages[:routes_drive_time])
    json.routes_wait_time time_over_day(averages[:routes_wait_time].to_i)
    json.routes_speed_average averages[:routes_speed_average]
    json.vehicles_used averages[:vehicles_used]
    json.vehicles averages[:vehicles]
    json.emission averages[:routes_emission] ? number_to_human(averages[:routes_emission], precision: 4) : '-'
    json.total_cost averages[:routes_cost]&.round(2)
    json.total_revenue averages[:routes_revenue]&.round(2)
    json.total_balance ((averages[:routes_revenue] || 0) - (averages[:routes_cost] || 0)).round(2)
    json.total_quantities planning_quantities(@planning, routes: stats_routes)
  end
end

json.planning_route_errors RouteSidebarSerializer.merge_planning_route_errors_from_models(stats_routes)
