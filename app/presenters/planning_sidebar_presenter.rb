class PlanningSidebarPresenter
  def initialize(planning:, routes:, current_user:, with_stops:, view_helpers:, with_planning: false, with_devices: true, external_callback: {})
    @planning = planning
    @routes = routes
    @current_user = current_user
    @with_stops = with_stops
    @view_helpers = view_helpers
    @with_planning = with_planning
    @with_devices = with_devices
    @external_callback_enabled = external_callback.fetch(:enabled, false)
    @external_callback_name = external_callback.fetch(:name, nil)
    @external_callback_url = external_callback.fetch(:url, nil)
    @external_callback_disabled = external_callback.fetch(:disabled, true)
  end

  def build
    customer = @planning.customer
    routes_array = @routes.to_a
    customer.custom_attributes.load

    routes_data = routes_array.map do |route|
      RouteSidebarSerializer.new(
        route: route,
        planning: @planning,
        with_stops: @with_stops,
        view_helpers: @view_helpers
      ).as_hash
    end

    duration_total = 0
    distance_total = 0
    size_total = 0
    size_active_total = 0

    routes_array.each do |route|
      distance_total += route.distance || 0
      route_data = route.route_data
      size_total += route_data&.stops_size || 0
      size_active_total += route_data&.size_active || 0
      next unless route.vehicle_usage

      duration_total += route.visits_duration.to_i
      duration_total += route.wait_time.to_i
      duration_total += route.drive_time.to_i
      duration_total += route.vehicle_usage.default_service_time_start.to_i
      duration_total += route.vehicle_usage.default_service_time_end.to_i
    end

    sidebar_locals = {
      prefered_unit: @current_user.prefered_unit,
      id: @planning.id,
      ref: @planning.ref,
      planning_id: @planning.id,
      customer_id: customer.id,
      duration: @view_helpers.time_over_day(duration_total),
      distance: @view_helpers.locale_distance(distance_total, @current_user.prefered_unit),
      size: size_total,
      size_active: size_active_total,
      routes: routes_data
    }

    sidebar_locals[:outdated] = true if @planning.outdated
    if customer.reseller.messagings.any? { |_k, value| value['enable'] == true }
      sidebar_locals[:customer_enable_sms] = customer.enable_sms
    end

    sidebar_locals[:customer_enable_external_callback] = @external_callback_enabled
    sidebar_locals[:customer_external_callback_name] = @external_callback_name
    sidebar_locals[:customer_external_callback_url] = @external_callback_url
    sidebar_locals[:customer_external_callback_disabled] = @external_callback_disabled

    if (averages = @planning.averages(@current_user.prefered_unit))
      sidebar_locals[:averages] = {
        routes_visits_duration: @view_helpers.time_over_day(averages[:routes_visits_duration].to_i),
        routes_rests_duration: @view_helpers.time_over_day(averages[:routes_rests_duration].to_i),
        routes_drive_time: @view_helpers.time_over_day(averages[:routes_drive_time]),
        routes_wait_time: @view_helpers.time_over_day(averages[:routes_wait_time].to_i),
        routes_speed_average: averages[:routes_speed_average],
        vehicles_used: averages[:vehicles_used],
        vehicles: averages[:vehicles],
        emission: averages[:routes_emission] ? @view_helpers.number_to_human(averages[:routes_emission], precision: 4) : '-',
        total_cost: averages[:routes_cost]&.round(2),
        total_revenue: averages[:routes_revenue]&.round(2),
        total_balance: ((averages[:routes_revenue] || 0) - (averages[:routes_cost] || 0)).round(2),
        total_quantities: @view_helpers.planning_quantities(@planning)
      }
    end

    if Job.on_planning(customer.job_optimizer, @planning.id)
      sidebar_locals[:optimizer] = {
        id: customer.job_optimizer.id,
        progress: customer.job_optimizer.progress,
        attempts: customer.job_optimizer.attempts,
        error: !!customer.job_optimizer.failed_at,
        customer_id: customer.id,
        dispatch_params_delayed_job: {
          nb_route: Job.nb_routes(customer.job_optimizer),
          with_stops: @with_stops,
          route_ids: routes_array.map(&:id).join(',')
        }
      }
    end

    sidebar_locals
  end
end
