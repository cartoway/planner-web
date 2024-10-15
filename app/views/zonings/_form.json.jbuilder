json.stores @planning ? @planning.routes.select(&:vehicle_usage).collect { |route| [route.vehicle_usage.default_store_start, route.vehicle_usage.default_store_stop, route.vehicle_usage.default_store_rest] }.flatten.compact.uniq : @zoning.customer.stores do |store|
  json.extract! store, :id, :name, :street, :postalcode, :city, :country, :lat, :lng, :color, :icon, :icon_size
end
index = 0
json.zoning @zoning.zones do |zone|
  json.extract! zone, :id, :zoning_id, :name, :vehicle_id, :polygon, :speed_multiplier
  json.index index += 1
  json.planning_id @planning.id if @planning
end
if @planning
  json.planning_id @planning.id
  json.planning @planning.routes do |route|
    if route.vehicle_usage_id
      json.vehicle_id route.vehicle_usage.vehicle_id
    end
    json.stops route.stops.select { |stop| stop.is_a?(StopVisit) }.collect do |stop|
      visit = stop.visit
      json.extract! visit, :id
      json.extract! visit.destination, :id, :name, :street, :detail, :postalcode, :city, :country, :lat, :lng, :phone_number, :comment
      json.ref visit.ref if @zoning.customer.enable_references
      json.active route.vehicle_usage_id && stop.active
      unless @planning.customer.enable_orders
        json.quantities visit.default_quantities.map { |k, v|
          {deliverable_unit_id: k, quantity: v, unit_icon: @deliverable_unit_icons[k]} unless v.nil?
        }.compact do |quantity|
          json.extract! quantity, :deliverable_unit_id, :quantity, :unit_icon
        end
      end
      (json.duration visit.default_duration_time_with_seconds) if visit.default_duration_time_with_seconds
      (json.time_window_start_1 stop.time_window_start_1_time) if stop.time_window_start_1
      (json.time_window_end_1 stop.time_window_end_1_time) if stop.time_window_end_1
      (json.time_window_start_2 stop.time_window_start_2_time) if stop.time_window_start_2
      (json.time_window_end_2 stop.time_window_end_2_time) if stop.time_window_end_2
      (json.priority stop.priority) if stop.priority
      (json.color visit.color) if visit.color
      (json.icon visit.icon) if visit.icon
    end
  end
end
