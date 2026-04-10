  routes_relation = planning.routes
  stops_filter = @params.key?(:stops) ? @params[:stops].split('|') : []

  routes_relation.find_in_batches(batch_size: summary ? 100 : 30) do |batch|
    Preloaders::RouteBatchPreload.preload!(batch, summary: summary)
    sorted_batch = batch.sort_by { |route|
      [
        route.vehicle_usage_id.nil? ? 0 : 1,
        route.vehicle_usage_id || 0,
        route.id
      ]
    }

    sorted_batch.each do |route|
      next unless route.stops_size > 0
      next if !route.vehicle_usage_id && @params.key?(:stops) && !stops_filter.include?('out-of-route')

      if summary
        render partial: 'routes/summary', formats: [:csv], locals: { route: route, csv: csv }
      else
        render partial: 'routes/show', formats: [:csv], locals: { route: route, csv: csv }
      end
    end
  end
