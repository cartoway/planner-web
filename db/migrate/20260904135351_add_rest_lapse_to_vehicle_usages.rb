class AddRestLapseToVehicleUsages < ActiveRecord::Migration[6.1]
  def up
    add_column :vehicle_usages, :rest_lapse, :integer unless column_exists?(:vehicle_usages, :rest_lapse)
    add_column :vehicle_usage_sets, :rest_lapse, :integer unless column_exists?(:vehicle_usage_sets, :rest_lapse)
  end

  def down
    remove_column :vehicle_usages, :rest_lapse if column_exists?(:vehicle_usages, :rest_lapse)
    remove_column :vehicle_usage_sets, :rest_lapse if column_exists?(:vehicle_usage_sets, :rest_lapse)
  end
end
