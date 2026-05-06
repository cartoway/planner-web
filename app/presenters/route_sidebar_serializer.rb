class RouteSidebarSerializer
  def initialize(route:, planning:, with_stops:, view_helpers:)
    @route = route
    @planning = planning
    @with_stops = with_stops
    @h = view_helpers
  end

  def as_hash
    route_data = @route.route_data
    vehicle_usage = @route.vehicle_usage
    vehicle = vehicle_usage&.vehicle
    route_stops = @with_stops ? @route.stops.to_a : []
    effective_color = @route.color || vehicle&.color
    default_color = vehicle&.color

    data = {
      route_id: @route.id,
      planning_id: @planning.id,
      ref: @route.ref,
      name: vehicle_usage ? [@route.ref, vehicle&.name].compact.join(' ') : I18n.t('plannings.edit.out_of_route'),
      hidden: @route.hidden,
      locked: @route.locked,
      outdated: @route.outdated,
      with_stops: @with_stops,
      vehicle_usage_id: vehicle_usage&.id,
      vehicle_id: vehicle&.id,
      vehicle_name: vehicle&.name,
      router_name: vehicle&.default_router&.name,
      default_color: default_color,
      color: effective_color,
      color_fake: @route.color,
      distance: @h.locale_distance(@route.distance || 0, @h.current_user.prefered_unit),
      duration: @h.time_over_day(route_duration_seconds(vehicle_usage)),
      visits_duration: @h.time_over_day(@route.visits_duration.to_i),
      rests_duration: @h.time_over_day(@route.rests_duration.to_i),
      wait_time: @h.time_over_day(@route.wait_time.to_i),
      drive_time: @route.drive_time.to_i.positive? ? @h.time_over_day(@route.drive_time.to_i) : nil,
      start_time: route_data&.start_time,
      end_time: route_data&.end_time,
      end_day: @h.number_of_days(@route.end),
      time_day: @h.number_of_days(@route.start),
      size: route_data&.stops_size.to_i,
      size_active: route_data&.size_active.to_i,
      skills: vehicle_usage_skills(vehicle_usage),
      devices: {},
      store_start: serialize_store_start(vehicle_usage, vehicle, route_data),
      store_stop: serialize_store_stop(vehicle_usage, vehicle, route_data),
      used_reloads: route_data&.size_store_reloads.to_i,
      route_averages: serialize_route_averages,
      status_any: false,
      status_all: [],
      stops: serialize_stops(route_stops)
    }

    data[:start_with_service] = formatted_display_start_time
    data[:start_with_service_day] = day_from_display_start_time
    data[:end_without_service] = formatted_display_end_time
    data[:end_without_service_day] = day_from_display_end_time
    data[:departure] = route_data&.departure_time if route_data&.start_time
    data[:time_window_start] = vehicle_usage&.default_time_window_start_time
    data[:optimized_at_formatted] = @route.optimized_at && @h.l(@route.optimized_at)
    data[:last_sent_at_formatted] = @route.last_sent_at && @h.l(@route.last_sent_at)
    data[:last_sent_to] = @route.last_sent_to
    data[:route_error] = route_error?
    merge_route_errors!(data)
    data
  end

  private

  def route_duration_seconds(vehicle_usage)
    @route.visits_duration.to_i +
      @route.wait_time.to_i +
      @route.drive_time.to_i +
      vehicle_usage&.default_service_time_start.to_i +
      vehicle_usage&.default_service_time_end.to_i
  end

  def vehicle_usage_skills(vehicle_usage)
    return [] unless vehicle_usage

    [vehicle_usage.tags, vehicle_usage.vehicle&.tags].flatten.compact.map do |tag|
      {
        icon: tag.default_icon,
        label: tag.label,
        color: tag.default_color
      }
    end
  end

  def serialize_stops(route_stops)
    sorted_route_stops =
      if @route.vehicle_usage_id
        route_stops
      elsif route_stops.all? { |stop| stop.name.to_i != 0 }
        route_stops.sort_by { |stop| stop.name.to_i }
      else
        route_stops.sort_by { |stop| stop.name.to_s.downcase }
      end

    inactive_stops = 0
    sorted_route_stops.map do |stop|
      base = serialize_stop_common(stop)
      if stop.active
        base[:number] = stop.index - inactive_stops if @route.vehicle_usage_id
      else
        inactive_stops += 1
      end

      case stop
      when StopVisit
        serialize_visit_stop(base, stop)
      when StopRest
        base.merge(rest: { rest: true, store_id: @route.vehicle_usage&.default_store_rest&.id })
      when StopStore
        serialize_store_stop_data(base, stop)
      else
        base
      end
    end
  end

  def serialize_stop_common(stop)
    {
      stop_id: stop.id,
      stop_index: stop.index,
      route_id: @route.id,
      name: stop.name,
      geocoded: stop.position?,
      active: stop.active,
      error: stop_error?(stop),
      status: stop.status && I18n.t("plannings.edit.stop_status.#{stop.status.downcase}", default: stop.status),
      status_code: stop.status&.downcase,
      eta_formated: stop.eta && @h.l(stop.eta, format: :hour_minute),
      time: stop.time && stop.time_time,
      time_day: stop.time && @h.number_of_days(stop.time),
      wait_time: stop.wait_time && stop.wait_time > 60 ? format('%i:%02i', stop.wait_time / 3600, stop.wait_time / 60 % 60) : nil,
      time_window_start_end_1: !!stop.time_window_start_1 || !!stop.time_window_end_1,
      time_windows_condensed: @h.stop_condensed_time_windows(stop),
      out_of_window: stop.out_of_window,
      out_of_capacity: stop.out_of_capacity,
      out_of_drive_time: stop.out_of_drive_time,
      out_of_force_position: stop.out_of_force_position,
      out_of_work_time: stop.out_of_work_time,
      out_of_max_distance: stop.out_of_max_distance,
      out_of_max_ride_distance: stop.out_of_max_ride_distance,
      out_of_max_ride_duration: stop.out_of_max_ride_duration,
      out_of_max_reload: stop.out_of_max_reload,
      out_of_relation: stop.out_of_relation,
      no_path: stop.no_path,
      unmanageable_capacity: stop.unmanageable_capacity,
      out_of_skill: stop.out_of_skill,
      locked: stop.respond_to?(:locked) ? stop.locked : false
    }
  end

  def serialize_visit_stop(base, stop)
    visit = stop.visit
    destination = visit&.destination
    base.merge(
      visits: true,
      visit_id: visit&.id,
      destination: {
        destination_id: destination&.id,
        color: visit&.color,
        icon: visit&.icon
      },
      destination_name: destination&.name,
      destination_ref: destination&.ref.presence,
      visit_ref: visit&.ref.presence,
      index_visit: nil
    )
  end

  def serialize_store_stop_data(base, stop)
    rd = stop.route_data
    base.merge(
      store_reload_id: stop.store_reload&.id,
      icon: stop.store_reload&.store&.icon,
      store_reload: {
        store_reload: true,
        store_id: stop.store_reload&.store&.id,
        store_reload_id: stop.store_reload&.id,
        departure: stop.time && stop.store_reload ? @h.time_over_day(stop.time.to_i + stop.store_reload.default_duration.to_i) : nil,
        departure_day: stop.time && stop.store_reload ? @h.number_of_days(stop.time.to_i + stop.store_reload.default_duration.to_i) : nil
      },
      route_data: serialize_route_data(rd),
      status: (rd&.status || stop.status) && I18n.t("plannings.edit.stop_store_status.#{(rd&.status || stop.status).downcase}", default: rd&.status || stop.status),
      status_code: (rd&.status || stop.status)&.downcase
    )
  end

  def serialize_store_start(vehicle_usage, vehicle, route_data)
    store = vehicle_usage&.default_store_start
    return nil unless store

    {
      id: store.id,
      name: store.name,
      geocoded: store.position?,
      no_path: false,
      icon: store.icon,
      departure: route_data&.start_time,
      status_code: @route.start_route_data&.status&.downcase,
      eta_formated: @route.start_route_data&.eta && @h.l(@route.start_route_data.eta, format: :hour_minute),
      route_data: serialize_route_data(@route.start_route_data, vehicle: vehicle)
    }
  end

  def serialize_store_stop(vehicle_usage, vehicle, route_data)
    store = vehicle_usage&.default_store_stop
    return nil unless store

    {
      id: store.id,
      name: store.name,
      geocoded: store.position?,
      no_path: @route.stop_no_path,
      icon: store.icon,
      eta_formated: @route.stop_route_data&.eta && @h.l(@route.stop_route_data.eta, format: :hour_minute),
      status_code: @route.stop_route_data&.status&.downcase,
      route_data: serialize_route_data(@route.stop_route_data, vehicle: vehicle)
    }
  end

  def serialize_route_data(route_data, vehicle: @route.vehicle_usage&.vehicle)
    return {} unless route_data

    {
      id: route_data.id,
      route_id: @route.id,
      vehicle_id: vehicle&.id,
      hidden: route_data.hidden,
      color: route_data.color,
      duration: route_data.duration && @h.time_over_day(route_data.duration),
      distance: @h.locale_distance(route_data.distance || 0, @h.current_user.prefered_unit),
      route_out_of_drive_time: @route.stop_out_of_drive_time,
      route_out_of_work_time: @route.stop_out_of_work_time,
      route_out_of_max_distance: @route.stop_out_of_max_distance,
      work_or_window_time: @route.vehicle_usage&.work_or_window_time,
      quantities: vehicle ? @h.route_data_quantities(route_data, vehicle) : []
    }
  end

  def serialize_route_averages
    return nil unless @route.drive_time.to_i.positive?

    {
      drive_time: @h.time_over_day(@route.drive_time),
      prefered_unit: @h.current_user.prefered_unit,
      prefered_currency: @h.current_user.prefered_currency,
      speed: @route.speed_average(@h.current_user.prefered_unit),
      visits_duration: @h.time_over_day(@route.visits_duration.to_i),
      rests_duration: @h.time_over_day(@route.rests_duration.to_i),
      wait_time: @h.time_over_day(@route.wait_time.to_i)
    }
  end

  def route_error?
    @route.no_geolocalization || @route.out_of_window || @route.out_of_capacity || @route.out_of_drive_time ||
      @route.out_of_force_position || @route.out_of_work_time || @route.out_of_max_distance ||
      @route.out_of_max_ride_distance || @route.out_of_max_ride_duration || @route.out_of_max_reload ||
      @route.out_of_relation || @route.no_path || @route.unmanageable_capacity || @route.out_of_skill
  end

  def merge_route_errors!(data)
    data[:route_no_geolocalization] = @route.no_geolocalization
    data[:route_out_of_window] = @route.out_of_window
    data[:route_out_of_capacity] = @route.out_of_capacity
    data[:route_out_of_drive_time] = @route.out_of_drive_time
    data[:route_out_of_force_position] = @route.out_of_force_position
    data[:route_out_of_work_time] = @route.out_of_work_time
    data[:route_out_of_max_distance] = @route.out_of_max_distance
    data[:route_out_of_max_ride_distance] = @route.out_of_max_ride_distance
    data[:route_out_of_max_ride_duration] = @route.out_of_max_ride_duration
    data[:route_out_of_max_reload] = @route.out_of_max_reload
    data[:route_out_of_relation] = @route.out_of_relation
    data[:route_no_path] = @route.no_path
    data[:route_unmanageable_capacity] = @route.unmanageable_capacity
    data[:route_out_of_skill] = @route.out_of_skill
  end

  def stop_error?(stop)
    (stop.is_a?(StopVisit) && !stop.position?) || stop.out_of_window || stop.out_of_capacity || stop.out_of_drive_time ||
      stop.out_of_force_position || stop.out_of_work_time || stop.out_of_max_distance || stop.out_of_max_ride_distance ||
      stop.out_of_max_ride_duration || stop.out_of_max_reload || stop.out_of_relation || stop.no_path ||
      stop.unmanageable_capacity || stop.out_of_skill
  end

  def formatted_display_start_time
    time = @h.display_start_time(@route)
    time && Time.at(time).utc.strftime('%H:%M')
  end

  def day_from_display_start_time
    time = @h.display_start_time(@route)
    time && @h.number_of_days(time)
  end

  def formatted_display_end_time
    time = @h.display_end_time(@route)
    time && Time.at(time).utc.strftime('%H:%M')
  end

  def day_from_display_end_time
    time = @h.display_end_time(@route)
    time && @h.number_of_days(time)
  end
end
