json.routes @routes, partial: 'routes/edit', as: :route, locals: { stops_count: nil, planning: @routes.first.planning }
