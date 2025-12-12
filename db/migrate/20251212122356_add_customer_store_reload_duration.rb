class AddCustomerStoreReloadDuration < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :store_reload_duration, :integer
  end
end
