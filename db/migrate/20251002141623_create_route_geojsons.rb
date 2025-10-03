class CreateRouteGeojsons < ActiveRecord::Migration[6.1]
  def up
    create_table :route_geojsons do |t|
      t.references :route, null: false, foreign_key: true, index: { unique: true }
      t.jsonb :tracks, default: []
      t.jsonb :points, default: []
      t.timestamps
    end

    # Migrate existing data from routes table in batches
    batch_size = 100
    Route.find_in_batches(batch_size: batch_size) do |routes_batch|
      route_geojsons = routes_batch.map do |route|
        RouteGeojson.new(
          route_id: route.id,
          tracks: route.read_attribute(:geojson_tracks) || [],
          points: route.read_attribute(:geojson_points) || []
        )
      end
      RouteGeojson.import(route_geojsons) if route_geojsons.any?
    end

    remove_column :routes, :geojson_tracks, :text, array: true
    remove_column :routes, :geojson_points, :text, array: true
  end

  def down
    add_column :routes, :geojson_tracks, :text, array: true, default: []
    add_column :routes, :geojson_points, :text, array: true, default: []

    # Migrate data back from route_geojsons table in batches
    batch_size = 100
    RouteGeojson.find_in_batches(batch_size: batch_size) do |route_geojsons_batch|
      route_geojsons_batch.each do |route_geojson|
        Route.where(id: route_geojson.route_id).update_all(
          geojson_tracks: route_geojson.tracks,
          geojson_points: route_geojson.points
        )
      end
    end

    drop_table :route_geojsons
  end
end
