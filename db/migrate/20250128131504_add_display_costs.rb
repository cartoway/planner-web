class AddDisplayCosts < ActiveRecord::Migration[6.1]
  def change
    add_column :routes, :cost_distance, :float
    add_column :routes, :cost_fixed, :float
    add_column :routes, :cost_time, :float
    add_column :routes, :revenue, :float

    add_column :vehicle_usages, :cost_distance, :float
    add_column :vehicle_usages, :cost_fixed, :float
    add_column :vehicle_usages, :cost_time, :float

    add_column :vehicle_usage_sets, :cost_distance, :float
    add_column :vehicle_usage_sets, :cost_fixed, :float
    add_column :vehicle_usage_sets, :cost_time, :Float

    add_column :visits, :revenue, :float

    add_column :users, :prefered_currency, :integer, default: 0
  end
end
