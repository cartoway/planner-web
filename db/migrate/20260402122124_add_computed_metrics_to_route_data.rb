# frozen_string_literal: true

class AddComputedMetricsToRouteData < ActiveRecord::Migration[6.1]
  def up
    return if column_exists?(:route_data, :size_active)

    add_column :route_data, :size_active, :integer, null: false, default: 0
    add_column :route_data, :size_destinations, :integer, null: false, default: 0
    add_column :route_data, :size_store_reloads, :integer, null: false, default: 0
    add_column :route_data, :stops_size, :integer, null: false, default: 0

    add_column :route_data, :no_geolocalization, :boolean, null: false, default: false
    add_column :route_data, :no_path, :boolean, null: false, default: false
    add_column :route_data, :out_of_capacity, :boolean, null: false, default: false
    add_column :route_data, :out_of_drive_time, :boolean, null: false, default: false
    add_column :route_data, :out_of_force_position, :boolean, null: false, default: false
    add_column :route_data, :out_of_max_distance, :boolean, null: false, default: false
    add_column :route_data, :out_of_max_reload, :boolean, null: false, default: false
    add_column :route_data, :out_of_max_ride_distance, :boolean, null: false, default: false
    add_column :route_data, :out_of_max_ride_duration, :boolean, null: false, default: false
    add_column :route_data, :out_of_relation, :boolean, null: false, default: false
    add_column :route_data, :out_of_skill, :boolean, null: false, default: false
    add_column :route_data, :out_of_window, :boolean, null: false, default: false
    add_column :route_data, :out_of_work_time, :boolean, null: false, default: false
    add_column :route_data, :unmanageable_capacity, :boolean, null: false, default: false

    add_column :route_data, :max_loads, :jsonb, null: false, default: {}

    Route.update_all(outdated: true)
  end

  def down
    %w[
      out_of_skill out_of_relation out_of_max_reload out_of_max_distance
      out_of_work_time out_of_force_position out_of_drive_time out_of_window
      out_of_capacity out_of_max_ride_distance out_of_max_ride_duration
      unmanageable_capacity no_path no_geolocalization
      size_active size_destinations size_store_reloads stops_size
      max_loads
    ].each do |col|
      remove_column :route_data, col if column_exists?(:route_data, col)
    end
  end
end
