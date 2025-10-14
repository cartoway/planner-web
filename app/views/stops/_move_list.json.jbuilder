json.stops stops do |stop|
  next unless stop.is_a?(StopVisit)

  json.visits true
  (json.error true) if (stop.is_a?(StopVisit) && !stop.position?) || stop.out_of_window || stop.out_of_capacity || stop.out_of_drive_time || stop.out_of_force_position || stop.out_of_work_time || stop.out_of_max_distance || stop.out_of_max_ride_distance || stop.out_of_max_ride_duration || stop.out_of_max_reload || stop.out_of_relation || stop.no_path || stop.unmanageable_capacity
  json.stop_id stop.id
  json.route_id stop.route.id
  json.color_fake stop.route.color
  json.color stop.route.color || stop.route.vehicle_usage&.vehicle&.color
  json.stop_index stop.index
  json.extract! stop, :name, :street, :detail, :postalcode, :city, :country, :comment, :phone_number, :lat, :lng, :drive_time, :out_of_window, :out_of_capacity, :out_of_drive_time, :out_of_force_position, :out_of_work_time, :out_of_max_distance, :out_of_max_ride_distance, :out_of_max_ride_duration, :out_of_max_reload, :out_of_relation, :no_path, :unmanageable_capacity
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
  (json.priority stop.priority) if stop.priority
  (json.geocoded true) if stop.position?
  (json.time stop.time_time) if stop.time
  (json.time_day number_of_days(stop.time)) if stop.time
  json.active stop.active
  visit = stop.visit
  json.visit_id visit.id
  json.duration visit.default_duration
  json.destination do
    json.destination_id visit.destination.id
    (json.color visit.color) if visit.color
    (json.icon visit.icon) if visit.icon
  end
  json.index_visit visit.destination.visits.index(visit) + 1 if visit.destination.visits.size > 1
  tags = visit.destination.tags | visit.tags
  if !tags.empty?
    json.tags_present do
      json.tags do
        json.array! tags, :label
      end
    end
  end
  if stop.route.planning.customer.enable_orders
    order = stop.order
    if order
      json.orders order.products.collect(&:code).join(', ')
    end
  else
    # Hash { id, quantity, icon, label } for deliverable units
    json.quantities visit_quantities(visit, stop.route.vehicle_usage_id && stop.route.vehicle_usage.vehicle)
  end
  if stop.status && stop.route.planning.customer.enable_stop_status
    json.status t("plannings.edit.stop_status.#{stop.status.downcase}", default: stop.status)
    json.status_code stop.status.downcase
  end
  json.duration l(Time.at(stop.duration).utc, format: :hour_minute_second) if stop.duration > 0
end.compact
