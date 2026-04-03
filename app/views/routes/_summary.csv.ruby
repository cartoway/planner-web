row = {
  planning_ref: route.planning.ref,
  planning_name: route.planning.name,
  planning_date: route.planning.date && I18n.l(route.planning.date, format: :date),
  route: route.ref || (route.vehicle_usage_id && route.vehicle_usage.vehicle.name.gsub(%r{[\./\\\-*,!:?;]}, ' ')),
  ref_vehicle: (route.vehicle_usage.vehicle.ref if route.vehicle_usage_id),
  stop_size: route.stops_size,
  stop_active_size: route.size_active,
  time: route.end && route.start && time_over_day(route.end - route.start),
  distance: route.distance && (route.distance/1000).round(2),
  emission: route.emission&.round(2),
  start: route.route_data.start_absolute_time,
  end: route.route_data.end_absolute_time,
  visits_duration: route.route_data.visits_duration && time_over_day(route.route_data.visits_duration),
  wait_time: route.route_data.wait_time && time_over_day(route.route_data.wait_time),
  drive_time: route.route_data.drive_time && time_over_day(route.route_data.drive_time),
  out_of_window: route.out_of_window ? 'x' : '',
  out_of_max_ride_distance: route.out_of_max_ride_distance ? 'x' : '',
  out_of_max_ride_duration: route.out_of_max_ride_duration ? 'x' : '',
  out_of_max_reload: route.out_of_max_reload ? 'x' : '',
  cost_distance: route.cost_distance,
  cost_fixed: route.cost_fixed,
  cost_time: route.cost_time,
  revenue: route.revenue,
  tags: route.vehicle_usage && (route.vehicle_usage.tags | route.vehicle_usage.vehicle.tags).collect(&:label).join(',')
}

row.merge!(Hash[pickup_delivery_columns])
row.merge!(Hash[route.planning.customer.enable_orders ?
  [[:orders, nil]] :
  pickup_delivery_defs.flat_map{ |definition|
    du_id = definition[:du_id]
    [
      [definition[:max_load_header], route.max_loads[du_id]],
      [definition[:pickup_header], route.pickups[du_id]],
      [definition[:delivery_header], route.deliveries[du_id]]
    ]
  }
])
csv << @columns.map{ |c| row[c.to_sym] }
