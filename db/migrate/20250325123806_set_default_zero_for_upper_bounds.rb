class SetDefaultZeroForUpperBounds < ActiveRecord::Migration[6.1]
  def up
    Customer.where(stop_max_upper_bound: nil).update_all(stop_max_upper_bound: 0)
    Customer.where(vehicle_max_upper_bound: nil).update_all(vehicle_max_upper_bound: 0)

    change_column_default :customers, :stop_max_upper_bound, from: nil, to: 0
    change_column_default :customers, :vehicle_max_upper_bound, from: nil, to: 0
  end

  def down
    change_column_default :customers, :stop_max_upper_bound, from: 0, to: nil
    change_column_default :customers, :vehicle_max_upper_bound, from: 0, to: nil
  end
end
