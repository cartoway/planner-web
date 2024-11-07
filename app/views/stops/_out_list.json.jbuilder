json.route_id route.id
if @with_planning
  json.planning_id route.planning_id
end

json.color_fake route.color
if route.vehicle_usage_id
  json.name (route.ref ? "#{route.ref} " : '') + route.vehicle_usage.vehicle.name unless @with_planning
  json.color route.color || route.vehicle_usage.vehicle.color
  json.contact_email route.vehicle_usage.vehicle.contact_email if route.vehicle_usage.vehicle.contact_email
  json.vehicle_usage_id route.vehicle_usage.id
  if @with_devices
    json.devices route_devices(list_devices, route)
  end
  json.vehicle_id route.vehicle_usage.vehicle.id

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
    json.status_any status_uniq.size > 0 || route.planning.customer.device.available_stop_status?
  end
end
json.with_stops @with_stops
if @with_stops
  inactive_stops = 0
  json.stops route.vehicle_usage_id ? route.stops.sort_by{ |s| s.index || Float::INFINITY } : (route.stops.all?{ |s| s.name.to_i != 0 } ? route.stops.sort_by{ |s| s.name.to_i } : route.stops.sort_by{ |s| s.name.to_s.downcase }) do |stop|
    (json.error true) if (stop.is_a?(StopVisit) && !stop.position?) || stop.out_of_window || stop.out_of_capacity || stop.out_of_drive_time || stop.out_of_force_position || stop.out_of_work_time || stop.out_of_max_distance || stop.out_of_max_ride_distance || stop.out_of_max_ride_duration || stop.out_of_relation || stop.no_path || stop.unmanageable_capacity
    json.stop_id stop.id
    json.stop_index stop.index
    json.extract! stop, :name, :street, :detail, :postalcode, :city, :country, :comment, :phone_number, :lat, :lng, :drive_time, :out_of_window, :out_of_capacity, :out_of_drive_time, :out_of_force_position, :out_of_work_time, :out_of_max_distance, :out_of_max_ride_distance, :out_of_max_ride_duration, :out_of_relation, :no_path, :unmanageable_capacity
    json.ref stop.ref if route.planning.customer.enable_references
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
      if route.planning.customer.enable_orders
        order = stop.order
        if order
          json.orders order.products.collect(&:code).join(', ')
        end
      else
        # Hash { id, quantity, icon, label } for deliverable units
        json.quantities visit_quantities(visit, route.vehicle_usage_id && route.vehicle_usage.vehicle)
      end
      if stop.status && route.planning.customer.enable_stop_status
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
