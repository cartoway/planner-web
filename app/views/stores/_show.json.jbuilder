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
    json.name route.vehicle_usage.vehicle.name
    json.route_id route.id
    json.custom_attributes store.customer.custom_attributes.for_route.for_related_field('start_route_data').map { |c_a| custom_attribute_template(c_a, route, related_field: 'start_route_data') }
  end
elsif @store_stop_route
  json.store_stop do
    route = @store_stop_route
    json.name route.vehicle_usage.vehicle.name
    json.route_id route.id
    json.custom_attributes store.customer.custom_attributes.for_route.for_related_field('stop_route_data').map { |c_a| custom_attribute_template(c_a, route, related_field: 'stop_route_data') }
  end
end
