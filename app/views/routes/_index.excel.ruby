  routes_relation = planning.routes
  stops_filter = @params.key?(:stops) ? @params[:stops].split('|') : []

  routes_relation.find_in_batches(batch_size: 30) do |batch|

    # Rails 6 in_batches is poorly efficient with include_associations scopes, so we preload the associations manually
    ActiveRecord::Associations::Preloader.new.preload(
      batch,
      [
        {
          stops: [
            :route_data,
            {
              visit: [
                :relation_currents,
                :relation_successors,
                :tags,
                {
                  destination: [
                    :tags,
                    :visits,
                    { customer: :deliverable_units }
                  ]
                }
              ]
            },
            { store_reload: [:store] },
            { store: [:customer] }
          ]
        },
        {
          vehicle_usage: [
            :store_start,
            :store_stop,
            :store_rest,
            :store_reloads,
            :tags,
            { vehicle_usage_set: [:store_start, :store_stop, :store_rest, :store_reloads] },
            { vehicle: [:router, :tags, { customer: [:router, :deliverable_units] }] }
          ]
        }
      ]
    )

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
