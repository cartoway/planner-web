class AddVehiclesStoreDuration < ActiveRecord::Migration[6.1]
  def up
    add_column :vehicle_usages, :store_duration, :integer, default: nil
    add_column :vehicle_usage_sets, :store_duration, :integer, default: nil
  end

  def down
    remove_column :vehicle_usages, :store_duration
    remove_column :vehicle_usage_sets, :store_duration
  end
end
