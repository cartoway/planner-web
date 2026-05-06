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
  routes_for_sidebar = @routes || (@with_stops ? @planning.routes.includes_vehicle_usages.includes_destinations_and_stores.available : @planning.routes)
  customer_custom_attributes = @planning.customer.custom_attributes.to_a
  route_custom_attributes = customer_custom_attributes.select { |custom_attribute| custom_attribute.object_class == 'route' }
  start_route_custom_attributes = route_custom_attributes.select { |custom_attribute| custom_attribute.related_field == 'start_route_data' }
  stop_route_custom_attributes = route_custom_attributes.select { |custom_attribute| custom_attribute.related_field == 'stop_route_data' }
  customer_deliverable_units = @planning.customer.deliverable_units.to_a

  json.prefered_unit current_user.prefered_unit
  json.extract! @planning, :id, :ref
  json.planning_id @planning.id
  json.customer_id @planning.customer.id
  json.customer_enable_sms @planning.customer.enable_sms if @planning.customer.reseller.messagings.any?{ |_k, v| v['enable'] == true }
  if planning_external_callback_json_partial?
    json.customer_enable_external_callback current_user.customer.enable_external_callback?
    json.customer_external_callback_name current_user.customer.external_callback_name
    json.customer_external_callback_url current_user.customer.external_callback_url
    json.customer_external_callback_disabled planning_external_callback_segment_disabled?
  else
    json.customer_enable_external_callback false
    json.customer_external_callback_name nil
    json.customer_external_callback_url nil
    json.customer_external_callback_disabled true
  end
  duration = routes_for_sidebar.select(&:vehicle_usage).to_a.sum(0){ |route| route.visits_duration.to_i + route.wait_time.to_i + route.drive_time.to_i + route.vehicle_usage.default_service_time_start.to_i + route.vehicle_usage.default_service_time_end.to_i}
  json.duration time_over_day(duration)
  json.distance locale_distance(routes_for_sidebar.to_a.sum(0){ |route| route.distance || 0 }, current_user.prefered_unit)
  (json.outdated true) if @planning.outdated
  json.size routes_for_sidebar.to_a.sum(0) { |route| route.route_data&.stops_size || 0 }
  json.size_active routes_for_sidebar.to_a.sum(0) { |route| route.route_data&.size_active || 0 }

  json.routes routes_for_sidebar,
              partial: 'routes/edit',
              formats: [:json],
              handlers: [:jbuilder],
              as: :route,
              locals: {
                list_devices: planning_devices(@planning.customer),
                stops_count: nil,
                planning: @planning,
                start_route_custom_attributes: start_route_custom_attributes,
                stop_route_custom_attributes: stop_route_custom_attributes,
                customer_deliverable_units: customer_deliverable_units
              }
end
