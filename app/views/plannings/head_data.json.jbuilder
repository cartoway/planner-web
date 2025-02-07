json.prefered_unit current_user.prefered_unit
json.prefered_currency current_user.prefered_currency
json.extract! @planning, :id, :ref
json.planning_id @planning.id
duration = @planning.routes.includes_vehicle_usages.select(&:vehicle_usage).to_a.sum(0){ |route| route.visits_duration.to_i + route.wait_time.to_i + route.drive_time.to_i + route.vehicle_usage.default_service_time_start.to_i + route.vehicle_usage.default_service_time_end.to_i}
json.duration time_over_day(duration)
json.distance locale_distance(@planning.routes.to_a.sum(0){ |route| route.distance || 0 }, current_user.prefered_unit)
json.size @planning.routes.to_a.sum(0){ |route| route.stops_size }
json.size_active @planning.cached_active_stops_sum

averages = @planning.averages(current_user.prefered_unit)
if averages
  json.averages do
    json.routes_visits_duration time_over_day(averages[:routes_visits_duration]) if averages[:routes_visits_duration]
    json.routes_drive_time time_over_day(averages[:routes_drive_time])
    json.routes_wait_time time_over_day(averages[:routes_wait_time]) if averages[:routes_wait_time]
    json.routes_speed_average averages[:routes_speed_average]
    json.vehicles_used averages[:vehicles_used]
    json.vehicles averages[:vehicles]
    json.emission averages[:routes_emission] ? number_to_human(averages[:routes_emission], precision: 4) : '-'
    json.total_cost (averages[:routes_cost]).round(2)
    json.total_revenue averages[:routes_revenue] && (averages[:routes_revenue]).round(2)
    json.total_balance ((averages[:routes_revenue] || 0) - averages[:routes_cost]).round(2)
    json.total_quantities planning_quantities(@planning)
  end
end
