  planning.routes.includes_destinations.includes_deliverable_units.select{ |route| route.stops.size > 0 }.select{ |route|
  route.vehicle_usage_id || !@params.key?(:stops) || @params[:stops].split('|').include?('out-of-route')
  }.collect { |route|
  render partial: 'routes/show', formats: [:csv], locals: {route: route, csv: csv}
  }.join('')
