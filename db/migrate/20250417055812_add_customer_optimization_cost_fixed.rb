class AddCustomerOptimizationCostFixed < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :optimization_cost_fixed, :integer
  end
end
