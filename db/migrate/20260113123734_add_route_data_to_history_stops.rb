class AddRouteDataToHistoryStops < ActiveRecord::Migration[6.1]
  def up
    add_column :history_stops, :route_data, :jsonb
    add_column :history_stops, :start_route_data, :jsonb
    add_column :history_stops, :stop_route_data, :jsonb

    execute <<-SQL
      UPDATE history_stops
      SET
        route_data = jsonb_build_object(
          'distance', route->>'distance',
          'emission', route->>'emission',
          'cost_distance', route->>'cost_distance',
          'cost_fixed', route->>'cost_fixed',
          'cost_time', route->>'cost_time',
          'revenue', route->>'revenue',
          'start', route->>'start',
          'end', route->>'end',
          'drive_time', route->>'drive_time',
          'wait_time', route->>'wait_time',
          'visits_duration', route->>'visits_duration',
          'pickups', COALESCE(route->'pickups', '{}'::jsonb),
          'deliveries', COALESCE(route->'deliveries', '{}'::jsonb),
          'departure', route->>'departure'
        ),
        start_route_data = jsonb_build_object(
          'status', route->>'departure_status',
          'eta', route->>'departure_eta'
        ),
        stop_route_data = jsonb_build_object(
          'status', route->>'arrival_status',
          'eta', route->>'arrival_eta'
        ),
        route = route - 'distance' - 'emission' - 'cost_distance' - 'cost_fixed' - 'cost_time' - 'revenue' - 'start' - 'end' - 'drive_time' - 'wait_time' - 'visits_duration' - 'pickups' - 'deliveries' - 'departure' - 'departure_status' - 'departure_eta' - 'arrival_status' - 'arrival_eta'
    SQL
  end

  def down
    execute <<-SQL
      UPDATE history_stops
      SET
        route = COALESCE(route, '{}'::jsonb) ||
          COALESCE(route_data, '{}'::jsonb) ||
          jsonb_build_object(
            'departure_status', start_route_data->>'status',
            'departure_eta', start_route_data->>'eta',
            'arrival_status', stop_route_data->>'status',
            'arrival_eta', stop_route_data->>'eta'
          )
    SQL

    # Remove columns
    remove_column :history_stops, :route_data
    remove_column :history_stops, :start_route_data
    remove_column :history_stops, :stop_route_data
  end
end
