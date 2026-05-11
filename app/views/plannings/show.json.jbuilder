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
  routes_array = routes_for_sidebar.to_a
  @planning.customer.custom_attributes.load

  duration_total = 0
  distance_total = 0
  size_total = 0
  size_active_total = 0

  routes_array.each do |route|
    route_data = route.route_data
    vehicle_usage = route.vehicle_usage

    distance_total += route.distance || 0
    size_total += route_data&.stops_size || 0
    size_active_total += route_data&.size_active || 0

    next unless vehicle_usage

    duration_total += route.visits_duration.to_i
    duration_total += route.wait_time.to_i
    duration_total += route.drive_time.to_i
    duration_total += vehicle_usage.default_service_time_start.to_i
    duration_total += vehicle_usage.default_service_time_end.to_i
  end

  routes_data = routes_array.map do |route|
    RouteSidebarSerializer.new(
      route: route,
      planning: @planning,
      with_stops: @with_stops,
      view_helpers: self
    ).as_hash
  end

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
  json.duration time_over_day(duration_total)
  json.distance locale_distance(distance_total, current_user.prefered_unit)
  (json.outdated true) if @planning.outdated
  json.size size_total
  json.size_active size_active_total

  json.planning_route_errors RouteSidebarSerializer.merge_planning_route_errors_from_sidebar_routes(routes_data)
  json.routes routes_data
end
