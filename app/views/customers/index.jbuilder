json.customers @customers do |customer|
  json.extract! customer, :id, :name, :test, :max_vehicles
  json.lat customer.stores[0]&.lat
  json.lng customer.stores[0]&.lng
  json.isActiv (!customer.end_subscription || customer.end_subscription > Time.now) ? true : false
  json.page((@customer_pages && @customer_pages[customer.id]) || 1)
end
