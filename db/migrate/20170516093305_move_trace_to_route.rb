class MoveTraceToRoute < ActiveRecord::Migration
  def up
    add_column :routes, :geojson_tracks, :text, array: true unless column_exists? :routes, :geojson_tracks
    add_column :routes, :geojson_points, :text, array: true unless column_exists? :routes, :geojson_points
    add_column :routes, :stop_no_path, :boolean unless column_exists? :routes, :stop_no_path
    add_column :routes, :quantities, :hstore unless column_exists? :routes, :quantities

    add_column :stops, :no_path, :boolean unless column_exists? :stops, :no_path

    Route.connection.schema_cache.clear!
    Route.reset_column_information

    StopVisit.class_eval do
      def icon_size
      end
    end

    route_updated_at_copy = column_exists? :routes, :updated_at_copy
    stop_updated_at_copy = column_exists? :stops, :updated_at_copy
    new_routes = route_updated_at_copy ? "updated_at_copy IS NULL OR (updated_at - interval '10 seconds' > updated_at_copy)" : 'true'

    Route.where(new_routes).includes({stops: {visit: [:tags, {destination: [:visits, :tags, :customer]}]}}).find_each{ |route|
      previous_with_pos = route.vehicle_usage && route.vehicle_usage.default_store_start.try(&:position?)

      geojson_tracks = []
      route.stops.sort_by{ |s| s.route.vehicle_usage ? s.index : s.id }.each_with_index{ |stop, i|
        if stop.position? && stop.active?
          stop.no_path = route.vehicle_usage && !stop.trace && previous_with_pos
          previous_with_pos = stop if stop.position?

          if stop.trace
            geojson_tracks << {
              type: 'Feature',
              geometry: {
                type: 'LineString',
                polylines: stop.trace,
              },
              properties: {
                route_id: route.id,
                color: stop.route.default_color,
                drive_time: stop.drive_time,
                distance: stop.distance
              }.compact
            }.to_json
          end
        end

        stop.index = i + 1 unless stop.route.vehicle_usage
      }

      if route.stop_trace
        geojson_tracks << {
          type: 'Feature',
          geometry: {
            type: 'LineString',
            polylines: route.stop_trace,
          },
          properties: {
            route_id: route.id,
            color: route.default_color,
            drive_time: route.stop_drive_time,
            distance: route.stop_distance
          }.compact
        }.to_json
      elsif route.vehicle_usage && route.vehicle_usage.default_store_stop.try(&:position?) && route.stops.any?{ |s| s.active && s.position? }
        route.stop_no_path = true
      end

      route.geojson_tracks = geojson_tracks unless geojson_tracks.empty?

      inactive_stops = 0
      geojson_points = route.stops.select(&:position?).map do |stop|
        inactive_stops += 1 unless stop.active
        if stop.position?
          {
            type: 'Feature',
            geometry: {
              type: 'Point',
              coordinates: [stop.lng, stop.lat]
            },
            properties: {
              route_id: route.id,
              index: stop.index,
              active: stop.active,
              number: stop.active && stop.route.vehicle_usage ? stop.index - inactive_stops : nil,
              color: stop.is_a?(StopVisit) ? stop.default_color : nil,
              icon: stop.icon,
              icon_size: stop.icon_size
            }
          }.to_json
        end
      end.compact

      route.geojson_points = geojson_points unless geojson_points.empty?

      route.compute_quantities

      route.migration_skip = true
      route.save!(validate: false)
    }

    remove_column :routes, :updated_at_copy if route_updated_at_copy
    remove_column :stops, :updated_at_copy if stop_updated_at_copy

    change_column :stops, :index, :integer, null: false
    remove_column :stops, :trace
    remove_column :routes, :stop_trace
  end

  def down
    add_column :stops, :trace, :text
    add_column :routes, :stop_trace, :text
    change_column :stops, :index, :integer, null: true

    Route.includes({stops: {visit: [:tags, {destination: [:visits, :tags, :customer]}]}}).find_each{ |route|
      next unless route.geojson_tracks
      geojson_track_stop = nil

      if route.geojson_tracks
        geojson_tracks = route.geojson_tracks.map{ |s| JSON.parse(s) }
        if route.vehicle_usage && route.vehicle_usage.default_store_stop
          geojson_track_stop = geojson_tracks[-1]
          geojson_tracks = geojson_tracks[0..-2]
        end

        if geojson_tracks
          route.stops.select(&:position?).select(&:active).reject(&:no_path).zip(geojson_tracks).each{ |stop, coordinates|
            if stop && coordinates
              stop.trace = coordinates['geometry']['polylines']
            end
          }
        end

        route.stop_trace = geojson_track_stop['geometry']['polylines'] if geojson_track_stop
      end
      route.migration_skip = true
      route.save!(validate: false)
    }

    remove_column :routes, :geojson_tracks
    remove_column :routes, :geojson_points
    remove_column :routes, :stop_no_path
    remove_column(:routes, :quantities) if column_exists?(:routes, :quantities)

    remove_column :stops, :no_path
  end
end
