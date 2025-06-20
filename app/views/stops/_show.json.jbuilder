json.planning_id stop.route.planning_id
json.route_id stop.route_id
json.stop_id stop.id
json.destination true

if stop.route.vehicle_usage_id
  json.vehicle_name stop.route.vehicle_usage.vehicle.name
else
  json.automatic_insert true
end

(json.error true) if (stop.is_a?(StopVisit) && !stop.position?) || stop.out_of_window || stop.out_of_capacity || stop.out_of_drive_time || stop.out_of_force_position|| stop.out_of_work_time || stop.out_of_max_distance || stop.out_of_max_ride_distance || stop.out_of_max_ride_duration || stop.out_of_relation || stop.no_path

json.extract! stop, :name, :street, :detail, :postalcode, :city, :country, :comment, :phone_number, :lat, :lng, :drive_time, :out_of_window, :out_of_capacity, :out_of_drive_time, :out_of_force_position, :out_of_work_time, :out_of_max_distance, :out_of_max_ride_distance, :out_of_max_ride_duration, :out_of_relation, :no_path, :active
json.ref stop.ref if stop.route.planning.customer.enable_references
json.time_window_start_end_1 !!stop.time_window_start_1 || !!stop.time_window_end_1
(json.time_window_start_1 stop.time_window_start_1_time) if stop.time_window_start_1
(json.time_window_start_1_day number_of_days(stop.time_window_start_1)) if stop.time_window_start_1
(json.time_window_end_1 stop.time_window_end_1_time) if stop.time_window_end_1
(json.time_window_end_1_day number_of_days(stop.time_window_end_1)) if stop.time_window_end_1
json.time_window_start_end_2 !!stop.time_window_start_2 || !!stop.time_window_end_2
(json.time_window_start_2 stop.time_window_start_2_time) if stop.time_window_start_2
(json.time_window_start_2_day number_of_days(stop.time_window_start_2)) if stop.time_window_start_2
(json.time_window_end_2 stop.time_window_end_2_time) if stop.time_window_end_2
(json.time_window_end_2_day number_of_days(stop.time_window_end_2)) if stop.time_window_end_2
(json.time_windows_condensed stop_condensed_time_windows(stop))
(json.force_position stop.force_position) if stop.force_position
(json.priority stop.priority) if stop.priority
(json.priority_text stop.priority_text) if stop.priority
(json.wait_time '%i:%02i' % [stop.wait_time / 60 / 60, stop.wait_time / 60 % 60]) if stop.wait_time && stop.wait_time > 60
(json.time stop.time_time) if stop.time
(json.time_day number_of_days(stop.time)) if stop.time
(json.link_phone_number current_user.link_phone_number) if current_user.url_click2call
json.distance (stop.distance || 0) / 1000
duration = nil
case stop
when StopVisit
  json.visits true
  visit = stop.visit
  json.visit_id visit.id
  json.destination_id visit.destination.id
  json.color stop.default_color
  json.index_visit (visit.destination.visits.index(visit) + 1) if visit.destination.visits.size > 1
  json.revenue visit.revenue if visit.revenue
  json.prefered_currency t("all.unit.currency_symbol.#{current_user.prefered_currency}")
  tags = visit.destination.tags | visit.tags
  if !tags.empty?
    json.tags_present do
      json.tags do
        json.array! tags, :label
      end
    end
  end
  if stop.status
    json.status t("plannings.edit.stop_status.#{stop.status.downcase}", default: stop.status)
    json.status_code stop.status.downcase
    json.status_updated_at l(stop.status_updated_at, format: :hour_minute)
  end
  if stop.route.last_sent_to && stop.status && stop.eta
    (json.eta_formated l(stop.eta, format: :hour_minute)) if stop.eta
  end
  duration = visit.default_duration_time_with_seconds
  destination_duration =
    visit.destination.default_duration_time_with_seconds

  json.vehicle_usage_id stop.route.vehicle_usage_id
  if @show_isoline
    if stop.route.vehicle_usage_id
      json.isoline stop.route.vehicle_usage.vehicle.default_router.isochrone || stop.route.vehicle_usage.vehicle.default_router.isodistance
      json.isochrone stop.route.vehicle_usage.vehicle.default_router.isochrone
      json.isodistance stop.route.vehicle_usage.vehicle.default_router.isodistance
    else
      json.isoline stop.route.planning.customer.router.isochrone || stop.route.planning.customer.router.isodistance
      json.isochrone stop.route.planning.customer.router.isochrone
      json.isodistance stop.route.planning.customer.router.isodistance
    end
  end
  json.custom_attributes current_user.customer.custom_attributes.for_visit.map{ |c_a| custom_attribute_template(c_a, visit) }
when StopRest
  json.rest do
    json.rest true
    duration = stop.route.vehicle_usage.default_rest_duration_time_with_seconds
    (json.store_id stop.route.vehicle_usage.default_store_rest.id) if stop.route.vehicle_usage.default_store_rest
    (json.error true) if stop.route.vehicle_usage.default_store_rest && !stop.route.vehicle_usage.default_store_rest.position?
  end
when StopStore
  json.store do
    json.store true
    json.store_id stop.store.id
    json.color stop.default_color
    (json.error true) if !stop.store.position?
  end
end
if !stop.is_a?(StopRest)
  if stop.route.planning.customer.enable_orders
    order = stop.order
    if order
      json.orders order.products.collect(&:code).join(', ')
    end
  else
    json.loads stop_quantities(stop, stop.route.vehicle_usage_id && stop.route.vehicle_usage.vehicle)
  end
end
json.duration duration if duration
json.destination_duration destination_duration if destination_duration
