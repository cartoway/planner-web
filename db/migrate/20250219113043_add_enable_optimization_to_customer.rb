class AddEnableOptimizationToCustomer < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :enable_optimization_soft_upper_bound, :bool
    add_column :customers, :stop_max_upper_bound, :integer
    add_column :customers, :vehicle_max_upper_bound, :integer
  end
end
