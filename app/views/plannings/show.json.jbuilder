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

  stats_routes = planning_statistics_routes(@planning, routes_array, current_user)

  time_totals = planning_time_totals_for_routes(stats_routes)
  duration_total = time_totals[:duration_total]
  work_duration_total = time_totals[:work_duration_total]
  distance_total = 0
  stops_totals = RouteSidebarSerializer.planning_stops_totals_for_routes(stats_routes)

  stats_routes.each do |route|
    distance_total += route.distance || 0
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
  json.prefered_currency current_user.prefered_currency
  json.extract! @planning, :id, :ref, :vehicle_usage_set_id
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
  json.work_duration time_over_day(work_duration_total)
  json.distance locale_distance(distance_total, current_user.prefered_unit)
  (json.outdated true) if @planning.outdated
  json.size stops_totals[:size]
  json.size_active stops_totals[:size_active]

  json.planning_route_errors RouteSidebarSerializer.merge_planning_route_errors_from_sidebar_routes(routes_data)
  json.routes routes_data
end
