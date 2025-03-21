class AddCustomerPlanningDateOffset < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :planning_date_offset, :integer, default: 1
  end
end
