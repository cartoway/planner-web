if @vehicle_usage_set
  vehicle_vehicle_usages = Hash[@vehicle_usage_set.vehicle_usages.collect{ |vehicle_usage| [vehicle_usage.vehicle, vehicle_usage] }]
  vehicle_usages = @zones.select(&:vehicle).collect{ |zone| vehicle_vehicle_usages[zone.vehicle] }
end
stores = if @stores
           @stores
elsif vehicle_usages
  (vehicle_usages.collect(&:default_store_start) + vehicle_usages.collect(&:default_store_stop) + vehicle_usages.collect(&:default_store_rest)).compact.uniq
else
  @zoning.customer.stores
end
json.stores stores do |store|
  json.extract! store, :id, :name, :street, :postalcode, :city, :country, :lat, :lng, :color, :icon, :icon_size
end
json.zoning @zones do |zone|
  json.extract! zone, :id, :name, :vehicle_id, :polygon, :speed_multiplier
end
if @destinations
  json.destinations @destinations, partial: 'api_web/v01/destinations/show', as: :destination
end
