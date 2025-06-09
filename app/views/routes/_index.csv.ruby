  planning.routes.includes_destinations.includes_deliverable_units.select{ |route| route.stops_size > 0 }.select{ |route|
  route.vehicle_usage_id || !@params.key?(:stops) || @params[:stops].split('|').include?('out-of-route')
  }.collect { |route|
    if summary
      render partial: 'routes/summary', locals: {route: route, csv: csv}
    else
      render partial: 'routes/show', locals: {route: route, csv: csv}
    end
  }.join('')
