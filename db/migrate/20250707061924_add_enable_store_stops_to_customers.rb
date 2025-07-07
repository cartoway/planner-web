class AddEnableStoreStopsToCustomers < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :enable_store_stops, :boolean, default: false
  end
end
