# frozen_string_literal: true

class RemoveOutOfMaxRideFromRoutes < ActiveRecord::Migration[6.1]
  def up
    # history_live_routes selects routes.* so PG tracks a dependency on these columns
    execute 'DROP VIEW IF EXISTS history_live_routes CASCADE'

    remove_column :routes, :out_of_max_ride_distance if column_exists?(:routes, :out_of_max_ride_distance)
    remove_column :routes, :out_of_max_ride_duration if column_exists?(:routes, :out_of_max_ride_duration)

    view_sql_path = Rails.root.join('docker/superset/history_live_routes.sql')
    execute File.read(view_sql_path) if File.exist?(view_sql_path)
  end

  def down
    add_column :routes, :out_of_max_ride_distance, :boolean unless column_exists?(:routes, :out_of_max_ride_distance)
    add_column :routes, :out_of_max_ride_duration, :boolean unless column_exists?(:routes, :out_of_max_ride_duration)

    view_sql_path = Rails.root.join('docker/superset/history_live_routes.sql')
    execute File.read(view_sql_path) if File.exist?(view_sql_path)
  end
end
