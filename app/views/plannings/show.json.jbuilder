if Job.on_planning(@planning.customer.job_optimizer, @planning.id)
  json.optimizer do
    json.extract! @planning.customer.job_optimizer, :id, :progress, :attempts
    json.error !!@planning.customer.job_optimizer.failed_at
    json.customer_id @planning.customer.id
    json.dispatch_params_delayed_job do
      json.nb_route Job.nb_routes(@planning.customer.job_optimizer)
      json.with_stops @with_stops
      json.route_ids @routes.map(&:id).join(',') if @routes
    end
  end
else
  json.prefered_unit current_user.prefered_unit
  json.extract! @planning, :id, :ref
  json.planning_id @planning.id
  json.customer_id @planning.customer.id
  json.customer_enable_sms @planning.customer.enable_sms if @planning.customer.reseller.sms_api_key
  json.customer_enable_external_callback current_user.customer.default_callback_enabled?
  json.customer_external_callback_name current_user.customer.default_callback_name
  json.customer_external_callback_url current_user.customer.default_callback_url
  duration = @planning.routes.includes_vehicle_usages.select(&:vehicle_usage).to_a.sum(0){ |route| route.visits_duration.to_i + route.wait_time.to_i + route.drive_time.to_i + route.vehicle_usage.default_service_time_start.to_i + route.vehicle_usage.default_service_time_end.to_i}
  json.duration time_over_day(duration)
  json.distance locale_distance(@planning.routes.to_a.sum(0){ |route| route.distance || 0 }, current_user.prefered_unit)
  (json.outdated true) if @planning.outdated
  json.size @planning.routes.to_a.sum(0){ |route| route.stops.size }
  json.size_active @planning.cached_active_stops_sum
  json.stores (@planning.vehicle_usage_set.vehicle_usages.collect(&:default_store_start) + @planning.vehicle_usage_set.vehicle_usages.collect(&:default_store_stop) + @planning.vehicle_usage_set.vehicle_usages.collect(&:default_store_rest)).compact.uniq do |store|
    json.extract! store, :id, :name, :street, :postalcode, :city, :country, :lat, :lng, :color, :icon, :icon_size
  end

  json.routes (@routes || (@with_stops ? @planning.routes.includes_destinations : @planning.routes)), partial: 'routes/edit', formats: [:json], handlers: [:jbuilder], as: :route, locals: { list_devices: planning_devices(@planning.customer), stops_count: nil }
end
