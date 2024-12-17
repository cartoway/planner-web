  planning.routes.includes_destinations.includes_deliverable_units.select{ |route| route.stops_size > 0 }.select{ |route|
  route.vehicle_usage_id || !@params.key?(:stops) || @params[:stops].split('|').include?('out-of-route')
  }.collect { |route|
    render 'routes/show', route: route, csv: csv
  }.join('')
