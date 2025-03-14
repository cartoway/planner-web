class EditCustomerSoftUpperBoundCoefs < ActiveRecord::Migration[6.1]
  def change
    Customer.all.each do |customer|
      if customer.optimization_stop_soft_upper_bound.to_f > 0 || customer.optimization_vehicle_soft_upper_bound.to_f > 0
        customer.update_column(:enable_optimization_soft_upper_bound, true)

        customer.update_column(:stop_max_upper_bound, 0) if customer.optimization_stop_soft_upper_bound.to_f == 0
        customer.update_column(:vehicle_max_upper_bound, 0) if customer.optimization_vehicle_soft_upper_bound.to_f == 0
      end

      if customer.optimization_stop_soft_upper_bound.to_f == 0
        customer.update_column(:optimization_stop_soft_upper_bound, 0.3)
      end

      if customer.optimization_vehicle_soft_upper_bound.to_f == 0
        customer.update_column(:optimization_vehicle_soft_upper_bound, 0.3)
      end
    end
  end
end
