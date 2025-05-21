class AddCountersToCustomers < ActiveRecord::Migration[6.1]
  def up
    add_column :customers, :destinations_count, :integer, default: 0, null: false
    add_column :customers, :visits_count, :integer, default: 0, null: false
    add_column :customers, :plannings_count, :integer, default: 0, null: false
    add_column :customers, :vehicles_count, :integer, default: 0, null: false

    Customer.reset_column_information
    Customer.find_each do |customer|
      destinations_count = customer.destinations_count
      visits_count = Visit.joins(:destination).where(destinations: { customer_id: customer.id }).count
      plannings_count = customer.plannings.count
      vehicles_count = customer.vehicles.count

      Customer.where(id: customer.id).update_all(
        destinations_count: destinations_count,
        visits_count: visits_count,
        plannings_count: plannings_count,
        vehicles_count: vehicles_count
      )
    end
  end

  def down
    remove_column :customers, :destinations_count
    remove_column :customers, :visits_count
    remove_column :customers, :plannings_count
    remove_column :customers, :vehicles_count
  end
end
