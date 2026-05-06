customer = planning.customer
enable_orders = customer.enable_orders
enable_stop_status = customer.enable_stop_status
route_vehicle = route.vehicle_usage&.vehicle
configured_device_definitions = customer.device.configured_definitions
available_stop_status = customer.device.available_stop_status?
customer_deliverable_units = local_assigns[:customer_deliverable_units] || customer.deliverable_units.to_a
start_route_custom_attributes = local_assigns[:start_route_custom_attributes] || customer.custom_attributes.for_route.for_related_field('start_route_data')
stop_route_custom_attributes = local_assigns[:stop_route_custom_attributes] || customer.custom_attributes.for_route.for_related_field('stop_route_data')
start_route_custom_attribute_templates = start_route_custom_attributes.map { |c_a| custom_attribute_template(c_a, route, related_field: 'start_route_data') }
stop_route_custom_attribute_templates = stop_route_custom_attributes.map { |c_a| custom_attribute_template(c_a, route, related_field: 'stop_route_data') }
destination_visit_index_cache = {}
visit_quantities_cache = {}
route_data_quantities_cache = {}

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
json.extract! route, :ref, :hidden, :locked, :outdated
(json.duration time_over_day(route.visits_duration.to_i + route.wait_time.to_i + route.drive_time.to_i + (route.vehicle_usage ? route.vehicle_usage.default_service_time_start.to_i + route.vehicle_usage.default_service_time_end.to_i : 0)))
json.distance locale_distance(route.distance || 0, current_user.prefered_unit)
route_data_metrics = route.route_data
route_stops_size = route_data_metrics&.stops_size
route_size_destinations = route_data_metrics&.size_destinations
route_size_active = route_data_metrics&.size_active || 0
json.size_active route_size_active
json.size stops_count || route_stops_size || 0
json.size_destinations route_size_destinations if route_size_destinations && route_size_destinations != route_size_active
route_stops = @with_stops ? route.stops.to_a : []
(json.start_time route.route_data.start_time) if route.route_data.start
(json.start_day number_of_days(route.start)) if route.start
(json.end_time route.route_data.end_time) if route.route_data.end
(json.end_day number_of_days(route.end)) if route.end

json.color_fake route.color
json.last_sent_to route.last_sent_to if route.last_sent_to
json.last_sent_at_formatted l(route.last_sent_at) if route.last_sent_at
json.optimized_at_formatted l(route.optimized_at) if route.optimized_at
unless enable_orders
  json.quantities route_quantities(planning, route)
end
if route.vehicle_usage_id
  json.name [route.ref, route_vehicle.name].compact.join(' ') unless @with_planning
  json.default_color route_vehicle.color
  json.color route.color || route_vehicle.color
  json.contact_email route_vehicle.contact_email if route_vehicle.contact_email
  json.vehicle_usage_id route.vehicle_usage.id
  json.max_reload route.vehicle_usage.default_max_reload
  json.used_reloads route_data_metrics&.size_store_reloads || 0
  if @with_devices
    json.devices route_devices(list_devices, route)
  end
  json.vehicle_id route_vehicle.id
  json.visits_duration time_over_day(route.visits_duration.to_i)
  json.rests_duration time_over_day(route.rests_duration.to_i)
  json.wait_time time_over_day(route.wait_time.to_i)
  json.vehicle_name route_vehicle.name
  json.time_window_start route.vehicle_usage.default_time_window_start_time
  if route_vehicle&.default_router
    json.router_name route_vehicle.default_router.name_locale[I18n.locale.to_s] ||
                     route_vehicle.default_router.name_locale[I18n.default_locale.to_s] ||
                     route_vehicle.default_router.name
  end
  if route.drive_time != 0 && !route.drive_time.nil?
    json.route_averages do
      json.drive_time time_over_day(route.drive_time) if route.drive_time
      json.prefered_unit current_user.prefered_unit
      json.prefered_currency current_user.prefered_currency
      json.speed route.speed_average(current_user.prefered_unit)

      json.visits_duration time_over_day(route.visits_duration.to_i)
      json.rests_duration time_over_day(route.rests_duration.to_i)
      json.wait_time time_over_day(route.wait_time.to_i)
    end
  end
  json.emission route.emission ? number_to_human(route.emission, precision: 4) : '-'
  json.total_cost [route.cost_distance, route.cost_fixed, route.cost_time].compact.reduce(&:+)&.round(2)
  json.total_revenue route.revenue && route.revenue.round(2)
  json.total_balance ((route.revenue || 0) - [0, route.cost_distance, route.cost_fixed, route.cost_time].compact.reduce(&:+)).round(2)
  json.work_or_window_time route.vehicle_usage.work_or_window_time
  json.skills [route.vehicle_usage.tags, route.vehicle_usage.vehicle.tags].flatten.compact do |tag|
    json.icon tag.default_icon
    json.label tag.label
    json.color tag.default_color
  end

  # Devices
  configured_device_definitions.each do |key, definition|
    has_route_operation = !definition[:route_operations].empty?
    has_vehicle = definition[:forms][:vehicle]
    has_blank_key = definition[:forms][:vehicle].keys.all?{ |k| !route_vehicle.devices[k].blank? }

    if has_route_operation && has_vehicle && has_blank_key
      json.set!(key, true)

      if key == :deliver
        json.driver_token route.vehicle_usage.vehicle.driver_token
      end
    end
  end
  if @with_stops && @with_devices
    status_map = {}
    route_stops.each do |stop|
      next unless stop.status
      status_map[stop.status.downcase] ||= {
        code: stop.status.downcase,
        status: t("plannings.edit.stop_status.#{stop.status.downcase}", default: stop.status)
      }
    end

    json.status_all do
      json.array! (status_map.values + [:planned, :intransit, :started, :finished, :delivered, :exception, :rejected, :undelivered].map { |status|
        {
          code: status.to_s.downcase,
          status: t("plannings.edit.stop_status.#{status.to_s}")
        }
      }).uniq
    end
    json.status_any status_map.any? || available_stop_status
  end
else
  json.name t("plannings.edit.out_of_route")
end
json.store_start do
  json.extract! route.vehicle_usage.default_store_start, :id, :name, :street, :postalcode, :city, :country, :lat, :lng, :color, :icon, :icon_size
  if route.start_route_data&.status && enable_stop_status
    json.status_code route.start_route_data.status.downcase
    json.status t("plannings.edit.stop_status.#{route.start_route_data.status.downcase}", default: route.start_route_data.status.downcase)
    json.eta_formated l(route.start_route_data.eta, format: :hour_minute) if route.start_route_data.eta
    json.eta route.start_route_data.eta
  end
  (json.time route.route_data.start_time) if route.start
  (json.time_day number_of_days(route.route_data.start)) if route.start
  (json.geocoded true) if route.vehicle_usage.default_store_start.position?
  (json.error true) unless route.vehicle_usage.default_store_start.position?
  json.route_data do
    json.id route.start_route_data.id
    json.route_id route.id
    json.vehicle_id route.vehicle_usage.vehicle_id
    json.route_averages do
      json.drive_time time_over_day(route.start_route_data.drive_time) if route.start_route_data.drive_time
      json.prefered_unit current_user.prefered_unit
      json.prefered_currency current_user.prefered_currency
      json.speed speed_average(route.start_route_data, current_user.prefered_unit)

      json.visits_duration time_over_day(route.start_route_data.visits_duration.to_i)
      json.rests_duration time_over_day(route.start_route_data.rests_duration.to_i)
      json.wait_time time_over_day(route.start_route_data.wait_time.to_i)
    end
    json.duration time_over_day(route.start_route_data.duration) if route.start_route_data.duration
    json.distance locale_distance(route.start_route_data.distance || 0, current_user.prefered_unit)
    json.extract! route.start_route_data, :emission, :cost_distance, :cost_fixed, :cost_time, :revenue, :start, :end, :drive_time, :wait_time, :visits_duration, :rests_duration, :pickups, :deliveries, :departure, :status, :eta, :hidden, :color
    json.quantities(
      route_data_quantities_cache[route.start_route_data.id] ||= route_data_quantities(
        route.start_route_data,
        route_vehicle,
        units: customer_deliverable_units
      )
    )
  end
  json.custom_attributes start_route_custom_attribute_templates
end if route.vehicle_usage && route.vehicle_usage.default_store_start
(json.start_with_service Time.at(display_start_time(route)).utc.strftime('%H:%M')) if display_start_time(route)
(json.start_with_service_day number_of_days(display_start_time(route))) if display_start_time(route)
(json.departure route.route_data.departure_time if route.route_data.start_time)

json.with_stops @with_stops
if @with_stops
  inactive_stops = 0
  sub_tour_index_counter = 0
  sorted_route_stops =
    if route.vehicle_usage_id
      route_stops
    elsif route_stops.all? { |stop| stop.name.to_i != 0 }
      route_stops.sort_by { |stop| stop.name.to_i }
    else
      route_stops.sort_by { |stop| stop.name.to_s.downcase }
    end
  json.stops sorted_route_stops do |stop|
    (json.error true) if (stop.is_a?(StopVisit) && !stop.position?) || stop.out_of_window || stop.out_of_capacity || stop.out_of_drive_time || stop.out_of_force_position || stop.out_of_work_time || stop.out_of_max_distance || stop.out_of_max_ride_distance || stop.out_of_max_ride_duration || stop.out_of_max_reload || stop.out_of_relation || stop.no_path || stop.unmanageable_capacity || stop.out_of_skill
    json.stop_id stop.id
    json.stop_index stop.index
    json.extract! stop, :name, :street, :detail, :postalcode, :city, :country, :comment, :phone_number, :lat, :lng, :drive_time, :out_of_window, :out_of_capacity, :out_of_drive_time, :out_of_force_position, :out_of_work_time, :out_of_max_distance, :out_of_max_ride_distance, :out_of_max_ride_duration, :out_of_max_reload, :out_of_relation, :no_path, :unmanageable_capacity, :out_of_skill
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
    if stop.status && enable_stop_status
      json.status t("plannings.edit.stop_status.#{stop.status.downcase}", default: stop.status)
      json.status_code stop.status.downcase
    end
    case stop
    when StopVisit
      json.visits true
      visit = stop.visit
      json.locked stop.locked
      json.visit_id visit.id
      json.destination_name visit.destination.name
      json.destination_ref visit.destination.ref.presence
      json.visit_ref visit.ref.presence
      json.destination_duration visit.destination.default_duration_time_with_seconds
      json.duration visit.default_duration
      json.destination do
        json.destination_id visit.destination.id
        (json.color visit.color) if visit.color
        (json.icon visit.icon) if visit.icon
      end
      destination_visits_index =
        destination_visit_index_cache[visit.destination_id] ||= visit.destination.visits.each_with_index.to_h { |v, i| [v.id, i + 1] }
      json.index_visit destination_visits_index[visit.id] if destination_visits_index.size > 1
      visit_stop_tags_present_json!(json, visit)
      if enable_orders
        order = stop.order
        if order
          json.orders order.products.collect(&:code).join(', ')
        end
      else
        # Hash { id, quantity, pickup, delivery, icon, label } for deliverable units
        json.quantities(
          visit_quantities_cache[visit.id] ||= visit_quantities(visit, route_vehicle)
        )
      end
      if stop.route.last_sent_to && stop.status && stop.eta
        (json.eta_formated l(stop.eta, format: :hour_minute)) if stop.eta
      end
    when StopRest
      json.rest do
        json.rest true
        (json.store_id route.vehicle_usage.default_store_rest.id) if route.vehicle_usage.default_store_rest
        (json.geocoded true) if route.vehicle_usage.default_store_rest && route.vehicle_usage.default_store_rest.position?
        (json.error true) if route.vehicle_usage.default_store_rest && !route.vehicle_usage.default_store_rest.position?
      end
    when StopStore
      sub_tour_index_counter += 1
      json.sub_tour_index sub_tour_index_counter
      json.store_reload do
        json.store_reload true
        json.store_id stop.store_reload.store.id
        json.store_reload_id stop.store_reload.id
        (json.geocoded true) if stop.store_reload.store.position?
        (json.error true) if !stop.store_reload.store.position?
        (json.departure time_over_day(stop.time.to_i + stop.store_reload.default_duration.to_i))
        json.departure_day number_of_days(stop.time.to_i + stop.store_reload.default_duration.to_i)
        if (store_status = stop.route_data&.status || stop.status) && enable_stop_status
          json.status t("plannings.edit.stop_store_status.#{store_status.downcase}", default: store_status)
          json.status_code store_status.downcase
          json.eta_formated l(stop.route_data.eta, format: :hour_minute) if stop.route_data&.eta
          json.status_updated_at l(stop.status_updated_at, format: :hour_minute) if stop.status_updated_at
        end
      end
      json.route_data do
        json.route_id stop.route.id
        json.vehicle_id stop.route.vehicle_usage.vehicle_id
        json.route_averages do
          json.drive_time time_over_day(stop.route_data.drive_time) if stop.route_data.drive_time
          json.prefered_unit current_user.prefered_unit
          json.prefered_currency current_user.prefered_currency
          json.speed speed_average(stop.route_data, current_user.prefered_unit)

          json.visits_duration time_over_day(stop.route_data.visits_duration.to_i)
          json.rests_duration time_over_day(stop.route_data.rests_duration.to_i)
          json.wait_time time_over_day(stop.route_data.wait_time.to_i)
        end
        json.duration time_over_day(stop.route_data.duration) if stop.route_data.duration
        json.distance locale_distance(stop.route_data.distance || 0, current_user.prefered_unit)
        json.extract! stop.route_data, :id, :emission, :cost_distance, :cost_fixed, :cost_time, :revenue, :start, :end, :drive_time, :wait_time, :visits_duration, :rests_duration, :pickups, :deliveries, :departure, :status, :hidden, :color
        json.quantities(
          route_data_quantities_cache[stop.route_data.id] ||= route_data_quantities(
            stop.route_data,
            route_vehicle,
            units: customer_deliverable_units
          )
        )
      end
    end
    json.duration l(Time.at(stop.duration).utc, format: :hour_minute_second) if stop.duration > 0
    # Include route depot statuses and custom attributes for stop-popup display
    if route.vehicle_usage_id && enable_stop_status
      if route.vehicle_usage.default_store_start && (route.start_route_data&.status || start_route_custom_attributes.any?)
        json.store_start do
          json.name route.vehicle_usage.default_store_start.name
          if route.start_route_data&.status
            json.status t("plannings.edit.stop_store_status.#{route.start_route_data.status.downcase}", default: route.start_route_data.status)
            json.status_code route.start_route_data.status.downcase
            json.eta_formated l(route.start_route_data.eta, format: :hour_minute) if route.start_route_data.eta
          end
          json.custom_attributes start_route_custom_attribute_templates
        end
      end
      if route.vehicle_usage.default_store_stop && (route.stop_route_data&.status || stop_route_custom_attributes.any?)
        json.store_stop do
          json.name route.vehicle_usage.default_store_stop.name
          if route.stop_route_data&.status
            json.status t("plannings.edit.stop_store_status.#{route.stop_route_data.status.downcase}", default: route.stop_route_data.status)
            json.status_code route.stop_route_data.status.downcase
            json.eta_formated l(route.stop_route_data.eta, format: :hour_minute) if route.stop_route_data.eta
          end
          json.custom_attributes stop_route_custom_attribute_templates
        end
      end
    end
  end
end

json.store_stop do
  json.extract! route.vehicle_usage.default_store_stop, :id, :name, :street, :postalcode, :city, :country, :lat, :lng, :color, :icon, :icon_size
  if route.stop_route_data&.status && enable_stop_status
    json.status_code route.stop_route_data.status.downcase
    json.status t("plannings.edit.stop_status.#{route.stop_route_data.status.downcase}", default: route.stop_route_data.status.downcase)
    json.eta_formated l(route.stop_route_data.eta, format: :hour_minute) if route.stop_route_data.eta
    json.eta route.stop_route_data.eta
  end
  (json.time route.route_data.end_time) if route.route_data.end
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
  json.route_data do
    json.route_id route.id
    json.vehicle_id route.vehicle_usage.vehicle_id
    json.extract! route.stop_route_data, :status, :eta
  end
  json.custom_attributes stop_route_custom_attribute_templates
end if route.vehicle_usage_id && route.vehicle_usage.default_store_stop
(json.end_without_service Time.at(display_end_time(route)).utc.strftime('%H:%M')) if display_end_time(route)
(json.end_without_service_day number_of_days(display_end_time(route))) if display_end_time(route)

if route.no_geolocalization || route.out_of_window || route.out_of_capacity || route.out_of_drive_time || route.out_of_force_position || route.out_of_work_time || route.out_of_max_distance || route.out_of_max_ride_distance || route.out_of_max_ride_duration || route.out_of_max_reload || route.out_of_relation || route.no_path || route.unmanageable_capacity || route.out_of_skill
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
  json.route_out_of_max_reload route.out_of_max_reload
  json.route_of_relation route.out_of_relation
  json.route_out_of_skill route.out_of_skill
  json.route_no_path route.no_path
  json.route_unmanageable_capacity route.unmanageable_capacity
end
