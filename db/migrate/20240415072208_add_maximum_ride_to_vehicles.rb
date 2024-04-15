class AddMaximumRideToVehicles < ActiveRecord::Migration
  def change
    add_column :vehicles, :max_ride_duration, :integer, default: nil
    add_column :vehicles, :max_ride_distance, :integer, default: nil
    add_column :vehicle_usage_sets, :max_ride_duration, :integer, default: nil
    add_column :vehicle_usage_sets, :max_ride_distance, :integer, default: nil
    add_column :stops, :out_of_max_ride_distance, :boolean
    add_column :stops, :out_of_max_ride_duration, :boolean
    add_column :routes, :out_of_max_ride_distance, :boolean
    add_column :routes, :out_of_max_ride_duration, :boolean
  end
end
