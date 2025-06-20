class AddStopStoreId < ActiveRecord::Migration[6.1]
  def change
    add_column :stops, :store_id, :integer
  end
end
