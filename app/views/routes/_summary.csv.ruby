row = {
  ref_planning: route.planning.ref,
  planning: route.planning.name,
  planning_date: route.planning.date && I18n.l(route.planning.date, format: :date),
  route: route.ref || (route.vehicle_usage_id && route.vehicle_usage.vehicle.name.gsub(%r{[/\\\-*,!:?;.]}, ' ')),
  vehicle: (route.vehicle_usage.vehicle.ref if route.vehicle_usage_id),
  stop_size: route.stops_size,
  stop_active_size: route.size_active,
  time: route.end && route.start && time_over_day(route.end - route.start),
  distance: route.distance && (route.distance/1000).round(2),
  emission: route.emission&.round(2),
  start: route.start_absolute_time,
  end: route.end_absolute_time,
  visits_duration: route.visits_duration && time_over_day(route.visits_duration),
  wait_time: route.wait_time && time_over_day(route.wait_time),
  drive_time: route.drive_time && time_over_day(route.drive_time),
  out_of_window: route.out_of_window ? 'x' : '',
  out_of_max_ride_distance: route.out_of_max_ride_distance ? 'x' : '',
  out_of_max_ride_duration: route.out_of_max_ride_duration ? 'x' : '',
  cost_distance: route.cost_distance,
  cost_fixed: route.cost_fixed,
  cost_time: route.cost_time,
  revenue: route.revenue,
  tags: route.vehicle_usage && (route.vehicle_usage.tags | route.vehicle_usage.vehicle.tags).collect(&:label).join(',')
}

row.merge!(Hash[route.planning.customer.enable_orders ?
    [[:orders, nil]] :
    route.planning.customer.deliverable_units.flat_map{ |du|
      [
        [('max_load' + (du.label ? "[#{du.label}]" : "#{du.id}")).to_sym, route.max_loads[du.id]],
        [('pickup' + (du.label ? "[#{du.label}]" : "#{du.id}")).to_sym, route.pickups[du.id]],
        [('delivery' + (du.label ? "[#{du.label}]" : "#{du.id}")).to_sym, route.deliveries[du.id]]
      ]
    }
  ])
csv << @columns.map{ |c| row[c.to_sym] }
