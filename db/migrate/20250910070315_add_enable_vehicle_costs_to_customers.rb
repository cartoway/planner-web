class AddEnableVehicleCostsToCustomers < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :enable_vehicle_costs, :boolean, default: false, null: false
  end
end
