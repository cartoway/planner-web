if route.vehicle_usage_id && (!@params.key?(:stops) || @params[:stops].split('|').include?('store'))
  row = {
    ref_planning: route.planning.ref,
    planning: route.planning.name,
    planning_date: route.planning.date && I18n.l(route.planning.date, format: :date),
    route: route.ref || (route.vehicle_usage_id && route.vehicle_usage.vehicle.name.gsub(%r{[\./\\\-*,!:?;]}, ' ')),
    vehicle: (route.vehicle_usage.vehicle.ref if route.vehicle_usage_id),
    order: 0,
    stop_type: I18n.t('plannings.export_file.stop_type_store'),
    active: nil,
    wait_time: nil,
    time: route.start_absolute_time,
    distance: 0,
    drive_time: 0,
    out_of_window: nil,
    out_of_capacity: nil,
    out_of_drive_time: nil,
    out_of_force_position: nil,
    out_of_work_time: nil,
    out_of_max_distance: nil,
    out_of_max_ride_distance: nil,
    out_of_max_ride_duration: nil,
    out_of_relation: nil,

    ref: route.vehicle_usage.default_store_start && route.vehicle_usage.default_store_start.ref,
    name: route.vehicle_usage.default_store_start && route.vehicle_usage.default_store_start.name,
    street: route.vehicle_usage.default_store_start && route.vehicle_usage.default_store_start.street,
    detail: nil,
    postalcode: route.vehicle_usage.default_store_start && route.vehicle_usage.default_store_start.postalcode,
    city: route.vehicle_usage.default_store_start && route.vehicle_usage.default_store_start.city,
    destination_duration: nil
  }

  row.merge!(state: route.vehicle_usage.default_store_start && route.vehicle_usage.default_store_start.state) if route.planning.customer.with_state?

  row.merge!({
    country: route.vehicle_usage.default_store_start && route.vehicle_usage.default_store_start.country,
    lat: route.vehicle_usage.default_store_start && route.vehicle_usage.default_store_start.lat&.round(6),
    lng: route.vehicle_usage.default_store_start && route.vehicle_usage.default_store_start.lng&.round(6),
    comment: nil,
    phone_number: nil,
    tags: nil,

    ref_visit: nil,
    duration: nil,
    time_window_start_1: nil,
    time_window_end_1: nil,
    time_window_start_2: nil,
    time_window_end_2: nil,
    force_position: nil,
    priority: nil,
    tags_visit: nil
  })

  row.merge!(Hash[route.planning.customer.enable_orders ?
    [[:orders, nil]] :
    route.planning.customer.deliverable_units.flat_map{ |du|
      [
        [('quantity' + (du.label ? "[#{du.label}]" : "#{du.id}")).to_sym, nil]
      ]
    }
  ])

  row.merge!(
    Hash[route.planning.customer.custom_attributes.select(&:visit?).map{ |ca|
      ["custom_attributes_visit[#{ca.name}]".to_sym, nil]
    }
  ])

  csv << @columns.map{ |c| row[c.to_sym] }
end

index = 0
route.stops.each { |stop|
  if !@params.key?(:stops) || ((stop.active || !stop.route.vehicle_usage_id || @params[:stops].split('|').include?('inactive')) && (stop.route.vehicle_usage || @params[:stops].split('|').include?('out-of-route')) && (stop.is_a?(StopVisit) || @params[:stops].split('|').include?('rest')))
    row = {
      ref_planning: route.planning.ref,
      planning: route.planning.name,
      planning_date: route.planning.date && I18n.l(route.planning.date, format: :date),
      route: route.ref || (route.vehicle_usage_id && route.vehicle_usage.vehicle.name.gsub(%r{[\./\\\-*,!:?;]}, ' ')),
      vehicle: (route.vehicle_usage.vehicle.ref if route.vehicle_usage_id),
      order: (index+=1 if route.vehicle_usage_id),
      stop_type: stop.is_a?(StopVisit) ? I18n.t('plannings.export_file.stop_type_visit') : I18n.t('plannings.export_file.stop_type_rest'),
      active: ((stop.active ? '1' : '0') if route.vehicle_usage_id),
      wait_time: ("%i:%02i" % [stop.wait_time/60/60, stop.wait_time/60%60] if route.vehicle_usage_id && stop.wait_time),
      time: (stop.time_absolute_time if route.vehicle_usage_id && stop.time),
      distance: (stop.distance if route.vehicle_usage_id),
      drive_time: (stop.drive_time if route.vehicle_usage_id),
      out_of_window: stop.out_of_window ? 'x' : '',
      out_of_capacity: stop.out_of_capacity ? 'x' : '',
      out_of_drive_time: stop.out_of_drive_time ? 'x' : '',
      out_of_force_position: stop.out_of_force_position ? 'x' : '',
      out_of_work_time: stop.out_of_work_time ? 'x' : '',
      out_of_max_distance: stop.out_of_max_distance ? 'x' : '',
      out_of_max_ride_distance: stop.out_of_max_ride_distance ? 'x' : '',
      out_of_max_ride_duration: stop.out_of_max_ride_duration ? 'x' : '',
      out_of_relation: stop.out_of_relation ? 'x' : '',
      status: stop.status && I18n.t("plannings.edit.stop_status.#{stop.status.downcase}", default: stop.status),
      status_updated_at: stop.status_updated_at && I18n.l(stop.status_updated_at, format: :hour_minute),
      eta: stop.eta && I18n.l(stop.eta, format: :hour_minute),

      ref: stop.is_a?(StopVisit) ? stop.visit.destination.ref : stop.ref,
      name: stop.name,
      street: stop.street,
      detail: stop.detail,
      postalcode: stop.postalcode,
      city: stop.city,
      destination_duration: stop.is_a?(StopVisit) && stop.destination_duration
    }

    row.merge!(state: stop.state) if route.planning.customer.with_state?

    row.merge!({
      country: stop.country,
      lat: stop.lat&.round(6),
      lng: stop.lng&.round(6),
      comment: stop.comment,
      phone_number: stop.phone_number,
      tags: (stop.visit.destination.tags.collect(&:label).join(',') if stop.is_a?(StopVisit)),

      ref_visit: (stop.visit.ref if stop.is_a?(StopVisit)),
      duration: stop.is_a?(StopVisit) ? (stop.visit.duration ? stop.visit.duration_absolute_time_with_seconds : nil) : (route.vehicle_usage.default_rest_duration ? route.vehicle_usage.default_rest_duration_time_with_seconds : nil),
      time_window_start_1: (stop.time_window_start_1_absolute_time if stop.time_window_start_1),
      time_window_end_1: (stop.time_window_end_1_absolute_time if stop.time_window_end_1),
      time_window_start_2: (stop.time_window_start_2_absolute_time if stop.time_window_start_2),
      time_window_end_2: (stop.time_window_end_2_absolute_time if stop.time_window_end_2),
      force_position: (I18n.t("plannings.export_file.force_position_#{stop.force_position}") if stop.is_a?(StopVisit) && stop.force_position),
      priority: (stop.priority if stop.priority),
      revenue: (stop.visit.revenue if stop.is_a?(StopVisit)),
      tags_visit: (stop.visit.tags.collect(&:label).join(',') if stop.is_a?(StopVisit))
    })

    row.merge!(Hash[route.planning.customer.enable_orders ?
      [[:orders, stop.is_a?(StopVisit) && stop.order && stop.order.products.length > 0 ? stop.order.products.collect(&:code).join('/') : nil]] :
      route.planning.customer.deliverable_units.flat_map{ |du|
        [[('quantity' + (du.label ? "[#{du.label}]" : "#{du.id}")).to_sym, stop.is_a?(StopVisit) ? stop.visit.quantities[du.id] : nil]]
      }
    ])
    row.merge!(
      Hash[route.planning.customer.custom_attributes.select(&:visit?).map{ |ca|
        ["custom_attributes_visit[#{ca.name}]".to_sym, stop.visit && stop.visit.custom_attributes_typed_hash[ca.name]]
      }
    ])

    csv << @columns.map{ |c| row[c.to_sym] }
  end
}

if route.vehicle_usage_id && (!@params.key?(:stops) || @params[:stops].split('|').include?('store'))
  row = {
    ref_planning: route.planning.ref,
    planning: route.planning.name,
    planning_date: route.planning.date && I18n.l(route.planning.date, format: :date),
    route: route.ref || (route.vehicle_usage_id && route.vehicle_usage.vehicle.name.gsub(%r{[\./\\\-*,!:?;]}, ' ')),
    vehicle: (route.vehicle_usage.vehicle.ref if route.vehicle_usage_id),
    order: index+1,
    stop_type: I18n.t('plannings.export_file.stop_type_store'),
    active: nil,
    wait_time: nil,
    time: (route.end_absolute_time if route.end),
    distance: route.stop_distance,
    drive_time: route.stop_drive_time,
    out_of_window: nil,
    out_of_capacity: nil,
    out_of_drive_time: route.stop_out_of_drive_time ? 'x' : '',
    out_of_force_position: '',
    out_of_work_time: route.stop_out_of_work_time ? 'x' : '',
    out_of_max_distance: route.stop_out_of_max_distance ? 'x' : '',
    out_of_max_ride_distance: '',
    out_of_max_ride_duration: '',
    out_of_relation: '',

    ref: route.vehicle_usage.default_store_stop && route.vehicle_usage.default_store_stop.ref,
    name: route.vehicle_usage.default_store_stop && route.vehicle_usage.default_store_stop.name,
    street: route.vehicle_usage.default_store_stop && route.vehicle_usage.default_store_stop.street,
    detail: nil,
    postalcode: route.vehicle_usage.default_store_stop && route.vehicle_usage.default_store_stop.postalcode,
    city: route.vehicle_usage.default_store_stop && route.vehicle_usage.default_store_stop.city,
    destination_duration: nil
    }

  row.merge!(state: route.vehicle_usage.default_store_stop && route.vehicle_usage.default_store_stop.state) if route.planning.customer.with_state?

  row.merge!({
    country: route.vehicle_usage.default_store_stop && route.vehicle_usage.default_store_stop.country,
    lat: route.vehicle_usage.default_store_stop && route.vehicle_usage.default_store_stop.lat&.round(6),
    lng: route.vehicle_usage.default_store_stop && route.vehicle_usage.default_store_stop.lng&.round(6),
    comment: nil,
    phone_number: nil,
    tags: nil,

    ref_visit: nil,
    duration: nil,
    time_window_start_1: nil,
    time_window_end_1: nil,
    time_window_start_2: nil,
    time_window_end_2: nil,
    force_position: nil,
    priority: nil,
    tags_visit: nil
  })

  row.merge!(Hash[route.planning.customer.enable_orders ?
    [[:orders, nil]] :
    route.planning.customer.deliverable_units.flat_map{ |du|
      [
        [('quantity' + (du.label ? "[#{du.label}]" : "#{du.id}")).to_sym, nil]
      ]
    }
  ])

  row.merge!(
    Hash[route.planning.customer.custom_attributes.select(&:visit?).map{ |ca|
      ["custom_attributes_visit[#{ca.name}]".to_sym, nil]
    }
  ])

  csv << @columns.map{ |c| row[c.to_sym] }
end
