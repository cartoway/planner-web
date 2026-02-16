json.extract! store, :id, :name, :street, :postalcode, :city, :country, :lat, :lng, :color, :icon, :icon_size
json.store true
json.ref store.ref if store.customer.enable_references
if @show_isoline
  json.isoline store.customer.router.isochrone || store.customer.router.isodistance
  json.isochrone store.customer.router.isochrone
  json.isodistance store.customer.router.isodistance
end
if @store_start_route
  json.store_start do
    route = @store_start_route
    route_data = route.start_route_data
    json.name route.vehicle_usage.vehicle.name
    json.route_id route.id
    if route_data&.status
      json.status t("plannings.edit.stop_store_status.#{route_data.status.downcase}", default: route_data.status)
      json.status_code route_data.status.downcase
      json.eta_formated l(route_data.eta, format: :hour_minute) if route_data.eta
    end
    json.custom_attributes store.customer.custom_attributes.for_route.for_related_field('start_route_data').map { |c_a| custom_attribute_template(c_a, route, related_field: 'start_route_data') }
  end
elsif @store_stop_route
  json.store_stop do
    route = @store_stop_route
    route_data = route.stop_route_data
    json.name route.vehicle_usage.vehicle.name
    json.route_id route.id
    if route_data&.status
      json.status t("plannings.edit.stop_store_status.#{route_data.status.downcase}", default: route_data.status)
      json.status_code route_data.status.downcase
      json.eta_formated l(route_data.eta, format: :hour_minute) if route_data.eta
    end
    json.custom_attributes store.customer.custom_attributes.for_route.for_related_field('stop_route_data').map { |c_a| custom_attribute_template(c_a, route, related_field: 'stop_route_data') }
  end
end
