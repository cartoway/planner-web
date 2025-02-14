class AddOptimizationMinimalTimeToCustomer < ActiveRecord::Migration
  def change
    add_column :customers, :optimization_minimal_time, :integer

    Customer.find_each do |customer|
      if customer.optimization_time && customer.optimization_time != Planner::Application.config.optimize_minimal_time
        customer.update_columns optimization_minimal_time: (customer.optimization_time / 20)
      end
    end
  end
end
