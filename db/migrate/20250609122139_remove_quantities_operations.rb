class RemoveQuantitiesOperations < ActiveRecord::Migration[6.1]
  def change
    remove_column :visits, :quantities_operations, :jsonb
  end
end
