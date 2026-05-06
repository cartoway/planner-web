class RouteSidebarSerializer
  def initialize(route:, planning:, with_stops:, view_helpers:, stops_count: nil)
    @route = route
    @planning = planning
    @with_stops = with_stops
    @view_helpers = view_helpers
    @stops_count = stops_count
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
      distance: @view_helpers.locale_distance(@route.distance || 0, @view_helpers.current_user.prefered_unit),
      duration: @view_helpers.time_over_day(route_duration_seconds(vehicle_usage)),
      visits_duration: @view_helpers.time_over_day(@route.visits_duration.to_i),
      rests_duration: @view_helpers.time_over_day(@route.rests_duration.to_i),
      wait_time: @view_helpers.time_over_day(@route.wait_time.to_i),
      drive_time: @route.drive_time.to_i.positive? ? @view_helpers.time_over_day(@route.drive_time.to_i) : nil,
      work_or_window_time: vehicle_usage&.work_or_window_time,
      start_time: route_data&.start_time,
      end_time: route_data&.end_time,
      end_day: @view_helpers.number_of_days(@route.end),
      time_day: @view_helpers.number_of_days(@route.start),
      size: @stops_count || route_data&.stops_size.to_i,
      size_active: route_data&.size_active.to_i,
      size_destinations: route_size_destinations(route_data),
      skills: vehicle_usage_skills(vehicle_usage),
      devices: serialized_devices(vehicle_usage),
      store_start: serialize_store_start(vehicle_usage, vehicle, route_data),
      store_stop: serialize_store_stop(vehicle_usage, vehicle, route_data),
      used_reloads: route_data&.size_store_reloads.to_i,
      emission: @route.emission ? @view_helpers.number_to_human(@route.emission, precision: 4) : '-',
      total_cost: total_cost,
      total_revenue: @route.revenue&.round(2),
      total_balance: total_balance,
      quantities: route_quantities,
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
    data[:max_reload] = vehicle_usage&.default_max_reload if vehicle_usage
    data[:optimized_at_formatted] = @route.optimized_at && @view_helpers.l(@route.optimized_at)
    data[:last_sent_at_formatted] = @route.last_sent_at && @view_helpers.l(@route.last_sent_at)
    data[:last_sent_to] = @route.last_sent_to
    data[:contact_email] = vehicle&.contact_email if vehicle&.contact_email.present?
    merge_device_flags!(data, vehicle_usage, vehicle)
    merge_status_filters!(data, route_stops)
    data[:route_error] = route_error?
    merge_route_errors!(data)
    data
  end

  private

  def total_cost
    [@route.cost_distance, @route.cost_fixed, @route.cost_time].compact.reduce(&:+)&.round(2)
  end

  def total_balance
    ((@route.revenue || 0) - [0, @route.cost_distance, @route.cost_fixed, @route.cost_time].compact.reduce(&:+)).round(2)
  end

  def route_quantities
    return nil if @planning.customer.enable_orders

    @view_helpers.route_quantities(@planning, @route)
  end

  def serialized_devices(vehicle_usage)
    return {} unless vehicle_usage

    @view_helpers.route_devices(@view_helpers.planning_devices(@planning.customer), @route)
  end

  def merge_device_flags!(data, vehicle_usage, vehicle)
    return unless vehicle_usage && vehicle

    customer.device.configured_definitions.each do |key, definition|
      has_route_operation = definition[:route_operations].present?
      has_vehicle_form = definition[:forms][:vehicle]
      has_required_device_keys = definition[:forms][:vehicle].keys.all? { |k| vehicle.devices[k].present? }
      next unless has_route_operation && has_vehicle_form && has_required_device_keys

      data[key] = true
      data[:driver_token] = vehicle.driver_token if key == :deliver
    end
  end

  def merge_status_filters!(data, route_stops)
    return unless @with_stops

    status_map = {}
    route_stops.each do |stop|
      next unless stop.status

      code = stop.status.downcase
      status_map[code] ||= {
        code: code,
        status: I18n.t("plannings.edit.stop_status.#{code}", default: stop.status)
      }
    end

    default_statuses = %i[planned intransit started finished delivered exception rejected undelivered].map do |status|
      {
        code: status.to_s,
        status: I18n.t("plannings.edit.stop_status.#{status}")
      }
    end
    data[:status_all] = (status_map.values + default_statuses).uniq { |status| status[:code] }
    data[:status_any] = status_map.any? || customer.device.available_stop_status?
  end

  def route_size_destinations(route_data)
    return nil unless route_data
    return nil if route_data.size_destinations == route_data.size_active

    route_data.size_destinations
  end

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
    sub_tour_index_counter = 0
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
        sub_tour_index_counter += 1
        serialize_store_stop_data(base, stop, sub_tour_index_counter)
      else
        base
      end
    end
  end

  def serialize_stop_common(stop)
    data = {
      stop_id: stop.id,
      stop_index: stop.index,
      route_id: @route.id,
      name: stop.name,
      ref: stop.ref,
      street: stop.street,
      detail: stop.detail,
      postalcode: stop.postalcode,
      city: stop.city,
      country: stop.country,
      comment: stop.comment,
      phone_number: stop.phone_number,
      lat: stop.lat,
      lng: stop.lng,
      drive_time: stop.drive_time,
      geocoded: stop.position?,
      active: stop.active,
      error: stop_error?(stop),
      status: stop.status && I18n.t("plannings.edit.stop_status.#{stop.status.downcase}", default: stop.status),
      status_code: stop.status&.downcase,
      eta_formated: stop.eta && @view_helpers.l(stop.eta, format: :hour_minute),
      time: stop.time && stop.time_time,
      time_day: stop.time && @view_helpers.number_of_days(stop.time),
      wait_time: stop.wait_time && stop.wait_time > 60 ? format('%<hours>i:%<minutes>02i', hours: stop.wait_time / 3600, minutes: stop.wait_time / 60 % 60) : nil,
      time_window_start_end_1: !!stop.time_window_start_1 || !!stop.time_window_end_1,
      time_window_start_1: stop.time_window_start_1 && stop.time_window_start_1_time,
      time_window_start_1_day: stop.time_window_start_1 && @view_helpers.number_of_days(stop.time_window_start_1),
      time_window_end_1: stop.time_window_end_1 && stop.time_window_end_1_time,
      time_window_end_1_day: stop.time_window_end_1 && @view_helpers.number_of_days(stop.time_window_end_1),
      time_window_start_end_2: !!stop.time_window_start_2 || !!stop.time_window_end_2,
      time_window_start_2: stop.time_window_start_2 && stop.time_window_start_2_time,
      time_window_start_2_day: stop.time_window_start_2 && @view_helpers.number_of_days(stop.time_window_start_2),
      time_window_end_2: stop.time_window_end_2 && stop.time_window_end_2_time,
      time_window_end_2_day: stop.time_window_end_2 && @view_helpers.number_of_days(stop.time_window_end_2),
      time_windows_condensed: @view_helpers.stop_condensed_time_windows(stop),
      priority: stop.priority,
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
      locked: stop.respond_to?(:locked) ? stop.locked : false,
      link_phone_number: @view_helpers.current_user.url_click2call ? @view_helpers.current_user.link_phone_number : nil,
      distance: (stop.distance || 0) / 1000.0
    }
    data[:ref] = nil unless @planning.customer.enable_references
    data
  end

  def serialize_visit_stop(base, stop)
    visit = stop.visit
    destination = visit&.destination
    base.merge(
      visits: true,
      visit_id: visit&.id,
      destination_duration: destination&.default_duration_time_with_seconds,
      visit_duration: visit&.default_duration_time_with_seconds,
      index_visit: destination_visit_index(destination, visit),
      tags_present: visit_tags_present(visit),
      destination: {
        destination_id: destination&.id,
        color: visit&.color,
        icon: visit&.icon
      },
      destination_name: destination&.name,
      destination_ref: destination&.ref.presence,
      visit_ref: visit&.ref.presence,
      duration: visit&.default_duration,
      quantities: visit_quantities(visit)
    )
  end

  def serialize_store_stop_data(base, stop, sub_tour_index)
    rd = stop.route_data
    base.merge(
      sub_tour_index: sub_tour_index,
      store_reload_id: stop.store_reload&.id,
      icon: stop.store_reload&.store&.icon,
      store_reload: {
        store_reload: true,
        store_id: stop.store_reload&.store&.id,
        store_reload_id: stop.store_reload&.id,
        geocoded: stop.store_reload&.store&.position?,
        error: !stop.store_reload&.store&.position?,
        departure: stop.time && stop.store_reload ? @view_helpers.time_over_day(stop.time.to_i + stop.store_reload.default_duration.to_i) : nil,
        departure_day: stop.time && stop.store_reload ? @view_helpers.number_of_days(stop.time.to_i + stop.store_reload.default_duration.to_i) : nil,
        status_updated_at: stop.status_updated_at && @view_helpers.l(stop.status_updated_at, format: :hour_minute)
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
      street: store.street,
      postalcode: store.postalcode,
      city: store.city,
      country: store.country,
      lat: store.lat,
      lng: store.lng,
      color: store.color,
      geocoded: store.position?,
      error: !store.position?,
      no_path: false,
      icon: store.icon,
      icon_size: store.icon_size,
      departure: route_data&.start_time,
      status: @route.start_route_data&.status && I18n.t("plannings.edit.stop_status.#{@route.start_route_data.status.downcase}", default: @route.start_route_data.status.downcase),
      status_code: @route.start_route_data&.status&.downcase,
      eta_formated: @route.start_route_data&.eta && @view_helpers.l(@route.start_route_data.eta, format: :hour_minute),
      eta: @route.start_route_data&.eta,
      time: route_data&.start && route_data.start_time,
      time_day: route_data&.start && @view_helpers.number_of_days(route_data.start),
      route_data: serialize_route_data(@route.start_route_data, vehicle: vehicle),
      custom_attributes: start_route_custom_attribute_templates
    }
  end

  def serialize_store_stop(vehicle_usage, vehicle, route_data)
    store = vehicle_usage&.default_store_stop
    return nil unless store

    {
      id: store.id,
      name: store.name,
      street: store.street,
      postalcode: store.postalcode,
      city: store.city,
      country: store.country,
      lat: store.lat,
      lng: store.lng,
      color: store.color,
      geocoded: store.position?,
      error: !store.position? || @route.stop_no_path || @route.stop_out_of_drive_time || @route.stop_out_of_work_time || @route.stop_out_of_max_distance,
      no_path: @route.stop_no_path,
      icon: store.icon,
      icon_size: store.icon_size,
      eta_formated: @route.stop_route_data&.eta && @view_helpers.l(@route.stop_route_data.eta, format: :hour_minute),
      eta: @route.stop_route_data&.eta,
      status: @route.stop_route_data&.status && I18n.t("plannings.edit.stop_status.#{@route.stop_route_data.status.downcase}", default: @route.stop_route_data.status.downcase),
      status_code: @route.stop_route_data&.status&.downcase,
      time: @route.route_data&.end && @route.route_data.end_time,
      time_day: @route.end && @view_helpers.number_of_days(@route.end),
      stop_out_of_drive_time: @route.stop_out_of_drive_time,
      stop_out_of_work_time: @route.stop_out_of_work_time,
      stop_out_of_max_distance: @route.stop_out_of_max_distance,
      stop_distance: (@route.stop_distance || 0) / 1000.0,
      stop_drive_time: @route.stop_drive_time,
      route_data: serialize_route_data(@route.stop_route_data, vehicle: vehicle),
      custom_attributes: stop_route_custom_attribute_templates
    }
  end

  def serialize_route_data(route_data, vehicle: @route.vehicle_usage&.vehicle)
    return {} unless route_data

    {
      id: route_data.id,
      route_id: @route.id,
      vehicle_id: vehicle&.id,
      status: route_data.status,
      eta: route_data.eta,
      emission: route_data.emission,
      cost_distance: route_data.cost_distance,
      cost_fixed: route_data.cost_fixed,
      cost_time: route_data.cost_time,
      revenue: route_data.revenue,
      start: route_data.start,
      end: route_data.end,
      drive_time: route_data.drive_time,
      wait_time: route_data.wait_time,
      visits_duration: route_data.visits_duration,
      rests_duration: route_data.rests_duration,
      pickups: route_data.pickups,
      deliveries: route_data.deliveries,
      departure: route_data.departure,
      hidden: route_data.hidden,
      color: route_data.color,
      duration: route_data.duration && @view_helpers.time_over_day(route_data.duration),
      distance: @view_helpers.locale_distance(route_data.distance || 0, @view_helpers.current_user.prefered_unit),
      route_out_of_drive_time: @route.stop_out_of_drive_time,
      route_out_of_work_time: @route.stop_out_of_work_time,
      route_out_of_max_distance: @route.stop_out_of_max_distance,
      work_or_window_time: @route.vehicle_usage&.work_or_window_time,
      route_averages: serialize_route_data_averages(route_data),
      quantities: vehicle ? @view_helpers.route_data_quantities(route_data, vehicle) : []
    }
  end

  def serialize_route_data_averages(route_data)
    {
      drive_time: route_data.drive_time && @view_helpers.time_over_day(route_data.drive_time),
      prefered_unit: @view_helpers.current_user.prefered_unit,
      prefered_currency: @view_helpers.current_user.prefered_currency,
      speed: @view_helpers.speed_average(route_data, @view_helpers.current_user.prefered_unit),
      visits_duration: @view_helpers.time_over_day(route_data.visits_duration.to_i),
      rests_duration: @view_helpers.time_over_day(route_data.rests_duration.to_i),
      wait_time: @view_helpers.time_over_day(route_data.wait_time.to_i)
    }
  end

  def serialize_route_averages
    return nil unless @route.drive_time.to_i.positive?

    {
      drive_time: @view_helpers.time_over_day(@route.drive_time),
      prefered_unit: @view_helpers.current_user.prefered_unit,
      prefered_currency: @view_helpers.current_user.prefered_currency,
      speed: @route.speed_average(@view_helpers.current_user.prefered_unit),
      visits_duration: @view_helpers.time_over_day(@route.visits_duration.to_i),
      rests_duration: @view_helpers.time_over_day(@route.rests_duration.to_i),
      wait_time: @view_helpers.time_over_day(@route.wait_time.to_i)
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

  def destination_visit_index(destination, visit)
    return nil unless destination && visit

    destination_visits = destination.visits
    return nil unless destination_visits.size > 1

    destination_visits.index(visit)&.+(1)
  end

  def visit_tags_present(visit)
    return nil unless visit

    destination_tags = visit.destination&.tags.to_a
    visit_tags = visit.tags.to_a
    merged_tags = destination_tags | visit_tags
    return nil if merged_tags.empty?

    {
      tags: destination_tags.map { |tag| { label: tag.label } },
      tags_visit: visit_tags.map { |tag| { label: tag.label } },
      tags_merged: merged_tags.map { |tag| { label: tag.label } }
    }
  end

  def visit_quantities(visit)
    return nil if customer.enable_orders

    @view_helpers.visit_quantities(visit, @route.vehicle_usage&.vehicle)
  end

  def start_route_custom_attribute_templates
    @start_route_custom_attribute_templates ||=
      customer.custom_attributes
              .for_route
              .for_related_field('start_route_data')
              .map { |custom_attribute| @view_helpers.custom_attribute_template(custom_attribute, @route, related_field: 'start_route_data') }
  end

  def stop_route_custom_attribute_templates
    @stop_route_custom_attribute_templates ||=
      customer.custom_attributes
              .for_route
              .for_related_field('stop_route_data')
              .map { |custom_attribute| @view_helpers.custom_attribute_template(custom_attribute, @route, related_field: 'stop_route_data') }
  end

  def customer
    @planning.customer
  end

  def formatted_display_start_time
    time = @view_helpers.display_start_time(@route)
    time && Time.at(time).utc.strftime('%H:%M')
  end

  def day_from_display_start_time
    time = @view_helpers.display_start_time(@route)
    time && @view_helpers.number_of_days(time)
  end

  def formatted_display_end_time
    time = @view_helpers.display_end_time(@route)
    time && Time.at(time).utc.strftime('%H:%M')
  end

  def day_from_display_end_time
    time = @view_helpers.display_end_time(@route)
    time && @view_helpers.number_of_days(time)
  end
end
