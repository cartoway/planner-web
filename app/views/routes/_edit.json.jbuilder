json.route_id route.id
if @with_planning
  json.planning_id route.planning_id
  json.name (route.ref ? "#{route.ref} | " : '') + planning.name
  json.date I18n.l(planning.date) if planning.date
  json.tags planning.tags do |tag|
    json.icon tag.default_icon
    json.label tag.label
    json.color tag.default_color
  end
end
json.extract! route, :ref, :hidden, :locked, :outdated, :size_active
(json.duration time_over_day(route.visits_duration.to_i + route.wait_time.to_i + route.drive_time.to_i + (route.vehicle_usage ? route.vehicle_usage.default_service_time_start.to_i + route.vehicle_usage.default_service_time_end.to_i : 0)))
json.distance locale_distance(route.distance || 0, current_user.prefered_unit)
json.size stops_count || route.stops_size
json.size_destinations route.size_destinations if route.size_destinations != route.size_active
(json.start_time route.start_time) if route.start
(json.start_day number_of_days(route.start)) if route.start
(json.end_time route.end_time) if route.end
(json.end_day number_of_days(route.end)) if route.end

json.color_fake route.color
json.last_sent_to route.last_sent_to if route.last_sent_to
json.last_sent_at_formatted l(route.last_sent_at) if route.last_sent_at
json.optimized_at_formatted l(route.optimized_at) if route.optimized_at
unless planning.customer.enable_orders
  json.quantities route_quantities(planning, route)
end
if route.vehicle_usage_id
  json.name (route.ref ? "#{route.ref} " : '') + route.vehicle_usage.vehicle.name unless @with_planning
  json.color route.color || route.vehicle_usage.vehicle.color
  json.contact_email route.vehicle_usage.vehicle.contact_email if route.vehicle_usage.vehicle.contact_email
  json.vehicle_usage_id route.vehicle_usage.id
  if @with_devices
    json.devices route_devices(list_devices, route)
  end
  json.vehicle_id route.vehicle_usage.vehicle.id
  json.vehicle_name route.vehicle_usage.vehicle.name
  if route.vehicle_usage.vehicle&.default_router
    json.router_name route.vehicle_usage.vehicle.default_router.name_locale[I18n.locale.to_s] ||
                     route.vehicle_usage.vehicle.default_router.name_locale[I18n.default_locale.to_s] ||
                     route.vehicle_usage.vehicle.default_router.name
  end
  if route.drive_time != 0 && !route.drive_time.nil?
    json.route_averages do
      json.drive_time time_over_day(route.drive_time)
      json.prefered_unit current_user.prefered_unit
      json.speed route.speed_average(current_user.prefered_unit)

      json.visits_duration time_over_day(route.visits_duration) if route.visits_duration && route.visits_duration > 0
      json.wait_time time_over_day(route.wait_time) if route.wait_time
    end
  end
  json.emission route.emission ? number_to_human(route.emission, precision: 4) : '-'
  json.work_or_window_time route.vehicle_usage.work_or_window_time
  json.skills [route.vehicle_usage.tags, route.vehicle_usage.vehicle.tags].flatten.compact do |tag|
    json.icon tag.default_icon
    json.label tag.label
    json.color tag.default_color
  end

  # Devices
  planning.customer.device.configured_definitions.each do |key, definition|
    has_route_operation = !definition[:route_operations].empty?
    has_vehicle = definition[:forms][:vehicle]
    has_blank_key = definition[:forms][:vehicle].keys.all?{ |k| !route.vehicle_usage.vehicle.devices[k].blank? }

    if has_route_operation && has_vehicle && has_blank_key
      json.set!(key, true)

      if key == :deliver
        json.driver_token route.vehicle_usage.vehicle.driver_token
      end
    end
  end
  if @with_stops && @with_devices
    status_uniq = route.stops.map{ |stop|
        {
          code: stop.status.downcase,
          status: t("plannings.edit.stop_status.#{stop.status.downcase}", default: stop.status)
        } if stop.status
      }.uniq.compact
    json.status_all do
      # FIXME: to avoid refreshing select active stops, combined here with hardcoded status
      json.array! status_uniq | [:planned, :intransit, :started, :finished, :delivered, :exception, :rejected, :undelivered].map{ |status|
        {
          code: status.to_s.downcase,
          status: t("plannings.edit.stop_status.#{status.to_s}")
        }
      }
    end
    json.status_any status_uniq.size > 0 || planning.customer.device.available_stop_status?
  end
else
  json.name t("plannings.edit.out_of_route")
end
json.store_start do
  json.extract! route.vehicle_usage.default_store_start, :id, :name, :street, :postalcode, :city, :country, :lat, :lng, :color, :icon, :icon_size
  if route.departure_status && planning.customer.enable_stop_status
    json.status_code route.departure_status.downcase
    json.status t("plannings.edit.stop_status.#{route.departure_status.downcase}", default: route.departure_status.downcase)
    json.eta_formated l(route.departure_eta, format: :hour_minute) if route.departure_eta
    json.eta route.departure_eta
  end
  (json.time route.start_time) if route.start
  (json.time_day number_of_days(route.start)) if route.start
  (json.geocoded true) if route.vehicle_usage.default_store_start.position?
  (json.error true) unless route.vehicle_usage.default_store_start.position?
end if route.vehicle_usage && route.vehicle_usage.default_store_start
(json.start_with_service Time.at(display_start_time(route)).utc.strftime('%H:%M')) if display_start_time(route)
(json.start_with_service_day number_of_days(display_start_time(route))) if display_start_time(route)

json.with_stops @with_stops
if @with_stops
  inactive_stops = 0
  json.stops route.vehicle_usage_id ? route.stops.sort_by{ |s| s.index || Float::INFINITY } : (route.stops.all?{ |s| s.name.to_i != 0 } ? route.stops.sort_by{ |s| s.name.to_i } : route.stops.sort_by{ |s| s.name.to_s.downcase }) do |stop|
    (json.error true) if (stop.is_a?(StopVisit) && !stop.position?) || stop.out_of_window || stop.out_of_capacity || stop.out_of_drive_time || stop.out_of_force_position || stop.out_of_work_time || stop.out_of_max_distance || stop.out_of_max_ride_distance || stop.out_of_max_ride_duration || stop.out_of_relation || stop.no_path || stop.unmanageable_capacity
    json.stop_id stop.id
    json.stop_index stop.index
    json.extract! stop, :name, :street, :detail, :postalcode, :city, :country, :comment, :phone_number, :lat, :lng, :drive_time, :out_of_window, :out_of_capacity, :out_of_drive_time, :out_of_force_position, :out_of_work_time, :out_of_max_distance, :out_of_max_ride_distance, :out_of_max_ride_duration, :out_of_relation, :no_path, :unmanageable_capacity
    json.ref stop.ref if planning.customer.enable_references
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
    (json.wait_time '%i:%02i' % [stop.wait_time / 60 / 60, stop.wait_time / 60 % 60]) if stop.wait_time && stop.wait_time > 60
    (json.geocoded true) if stop.position?
    (json.time stop.time_time) if stop.time
    (json.time_day number_of_days(stop.time)) if stop.time
    if stop.active
      json.active true
      (json.number stop.index - inactive_stops) if route.vehicle_usage_id
    else
      inactive_stops += 1
    end
    (json.link_phone_number current_user.link_phone_number) if current_user.url_click2call
    json.distance (stop.distance || 0) / 1000
    if stop.is_a?(StopVisit)
      json.visits true
      visit = stop.visit
      json.visit_id visit.id
      json.duration visit.default_duration
      json.destination do
        json.destination_id visit.destination.id
        (json.color visit.color) if visit.color
        (json.icon visit.icon) if visit.icon
      end
      json.index_visit (visit.destination.visits.index(visit) + 1) if visit.destination.visits.size > 1
      tags = visit.destination.tags | visit.tags
      if !tags.empty?
        json.tags_present do
          json.tags do
            json.array! tags, :label
          end
        end
      end
      if planning.customer.enable_orders
        order = stop.order
        if order
          json.orders order.products.collect(&:code).join(', ')
        end
      else
        # Hash { id, quantity, icon, label } for deliverable units
        json.quantities visit_quantities(visit, route.vehicle_usage_id && route.vehicle_usage.vehicle)
      end
      if stop.status && planning.customer.enable_stop_status
        json.status t("plannings.edit.stop_status.#{stop.status.downcase}", default: stop.status)
        json.status_code stop.status.downcase
      end
      if stop.route.last_sent_to && stop.status && stop.eta
        (json.eta_formated l(stop.eta, format: :hour_minute)) if stop.eta
      end
    elsif stop.is_a?(StopRest)
      json.rest do
        json.rest true
        (json.store_id route.vehicle_usage.default_store_rest.id) if route.vehicle_usage.default_store_rest
        (json.geocoded true) if route.vehicle_usage.default_store_rest && route.vehicle_usage.default_store_rest.position?
        (json.error true) if route.vehicle_usage.default_store_rest && !route.vehicle_usage.default_store_rest.position?
      end
    end
    json.duration l(Time.at(stop.duration).utc, format: :hour_minute_second) if stop.duration > 0
  end
end

json.store_stop do
  json.extract! route.vehicle_usage.default_store_stop, :id, :name, :street, :postalcode, :city, :country, :lat, :lng, :color, :icon, :icon_size
  if route.arrival_status && planning.customer.enable_stop_status
    json.status_code route.arrival_status.downcase
    json.status t("plannings.edit.stop_status.#{route.arrival_status.downcase}", default: route.arrival_status.downcase)
    json.eta_formated l(route.arrival_eta, format: :hour_minute) if route.arrival_eta
    json.eta route.arrival_eta
  end
  (json.time route.end_time) if route.end
  (json.time_day number_of_days(route.end)) if route.end
  (json.geocoded true) if route.vehicle_usage.default_store_stop.position?
  (json.no_path true) if route.stop_no_path
  (json.error true) if !route.vehicle_usage.default_store_stop.position? || route.stop_no_path || route.stop_out_of_drive_time || route.stop_out_of_work_time || route.stop_out_of_max_distance
  json.stop_out_of_drive_time route.stop_out_of_drive_time
  json.stop_out_of_work_time route.stop_out_of_work_time
  json.stop_out_of_max_distance route.stop_out_of_max_distance
  out_of_drive_time |= route.stop_out_of_drive_time
  json.stop_distance (route.stop_distance || 0) / 1000
  json.stop_drive_time route.stop_drive_time
end if route.vehicle_usage_id && route.vehicle_usage.default_store_stop
(json.end_without_service Time.at(display_end_time(route)).utc.strftime('%H:%M')) if display_end_time(route)
(json.end_without_service_day number_of_days(display_end_time(route))) if display_end_time(route)

if route.no_geolocalization || route.out_of_window || route.out_of_capacity || route.out_of_drive_time || route.out_of_force_position || route.out_of_work_time || route.out_of_max_distance || route.out_of_max_ride_distance || route.out_of_max_ride_duration || route.out_of_relation || route.no_path || route.unmanageable_capacity
  json.route_error true
  json.route_no_geolocalization route.no_geolocalization
  json.route_out_of_window route.out_of_window
  json.route_out_of_capacity route.out_of_capacity
  json.route_out_of_drive_time route.out_of_drive_time
  json.route_out_of_force_position route.out_of_force_position
  json.route_out_of_work_time route.out_of_work_time
  json.route_out_of_max_distance route.out_of_max_distance
  json.route_out_of_max_ride_distance route.out_of_max_ride_distance
  json.route_out_of_max_ride_duration route.out_of_max_ride_duration
  json.route_of_relation route.out_of_relation
  json.route_no_path route.no_path
  json.route_unmanageable_capacity route.unmanageable_capacity
end
