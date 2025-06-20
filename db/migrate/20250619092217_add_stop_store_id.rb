class AddStopStoreId < ActiveRecord::Migration[6.1]
  def up
    add_column :stops, :store_id, :integer
    add_foreign_key :stops, :stores, on_delete: :cascade
  end

  def down
    remove_foreign_key :stops, :stores
    remove_column :stops, :store_id

    # Remove all StopStore records
    route_ids = StopStore.all.map do |stop_store|
      stop_store.route_id
    end
    Route.where(id: route_ids).update_all(outdated: true)
    StopStore.destroy_all
  end
end
