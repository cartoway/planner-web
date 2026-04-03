  routes_relation = planning.routes
  stops_filter = @params.key?(:stops) ? @params[:stops].split('|') : []
  pickup_delivery_defs = @customer.deliverable_units.map do |du|
    suffix = du.label ? "[#{du.label}]" : du.id.to_s
    {
      du_id: du.id,
      max_load_header: :"max_load#{suffix}",
      pickup_header: :"pickup#{suffix}",
      delivery_header: :"delivery#{suffix}"
    }
  end
  pickup_delivery_columns = pickup_delivery_defs.flat_map do |definition|
    [
      [definition[:max_load_header], nil],
      [definition[:pickup_header], nil],
      [definition[:delivery_header], nil]
    ]
  end

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
        render partial: 'routes/summary',
               formats: [:csv],
               handlers: [:ruby],
               locals: {
                route: route,
                csv: csv,
                pickup_delivery_defs: pickup_delivery_defs,
                pickup_delivery_columns: pickup_delivery_columns
              }
      else
        render partial: 'routes/show',
               formats: [:csv],
               handlers: [:ruby],
               locals: {
                route: route,
                csv: csv,
                pickup_delivery_defs: pickup_delivery_defs,
                pickup_delivery_columns: pickup_delivery_columns
              }
      end
    end
  end
