json.extract! store, :id, :name, :street, :postalcode, :city, :country, :lat, :lng, :color, :icon, :icon_size
json.store true
json.ref store.ref if store.customer.enable_references
if @show_isoline
  json.isoline store.customer.router.isochrone || store.customer.router.isodistance
  json.isochrone store.customer.router.isochrone
  json.isodistance store.customer.router.isodistance
end
