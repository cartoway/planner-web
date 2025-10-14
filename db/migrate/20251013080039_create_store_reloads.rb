class CreateStoreReloads < ActiveRecord::Migration[6.1]
  def up
    create_table :store_reloads do |t|
      t.references :store, null: false, foreign_key: { on_delete: :cascade }
      t.string :ref
      t.integer :time_window_start
      t.integer :time_window_end
      t.integer :duration

      t.timestamps
    end

    add_index :store_reloads, [:store_id, :ref], unique: true
    add_column :stops, :store_reload_id, :integer
    add_index :stops, :store_reload_id
    add_foreign_key :stops, :store_reloads, on_delete: :cascade
    add_column :stops, :out_of_max_reload, :boolean

    Stop.only_stop_stores.find_each do |stop|
      store_reload = StoreReload.where(store_id: stop.store_id, ref: nil).first
      store_reload ||= StoreReload.create!(
        store_id: stop.store_id
      )

      stop.update_columns(store_reload_id: store_reload.id)
    end

    remove_column :vehicle_usage_sets, :store_duration
    remove_column :vehicle_usages, :store_duration

    add_column :vehicle_usage_sets, :max_reload, :integer, null: true
    add_column :vehicle_usages, :max_reload, :integer, null: true

    create_table :store_reload_vehicle_usages do |t|
      t.references :store_reload, null: false, foreign_key: { on_delete: :cascade }
      t.references :vehicle_usage, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    add_index :store_reload_vehicle_usages, [:store_reload_id, :vehicle_usage_id], unique: true, name: 'index_store_reload_vehicle_usages_unique'

    create_table :store_reload_vehicle_usage_sets do |t|
      t.references :store_reload, null: false, foreign_key: { on_delete: :cascade }
      t.references :vehicle_usage_set, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end
    add_index :store_reload_vehicle_usage_sets, [:store_reload_id, :vehicle_usage_set_id], unique: true, name: 'index_store_reload_vehicle_usage_sets_unique'
  end

  def down
    Stop.only_stop_stores.find_each do |stop|
      stop.update_columns(store_id: stop.store_reload.store_id)
    end

    remove_foreign_key :stops, :store_reloads
    remove_index :stops, :store_reload_id if index_exists?(:stops, :store_reload_id)
    remove_column :stops, :store_reload_id
    remove_column :stops, :out_of_max_reload
    drop_table :store_reloads

    add_column :vehicle_usage_sets, :store_duration, :integer, default: nil
    add_column :vehicle_usages, :store_duration, :integer, default: nil

    remove_column :vehicle_usage_sets, :max_reload
    remove_column :vehicle_usages, :max_reload

    drop_table :store_reload_vehicle_usages
    drop_table :store_reload_vehicle_usage_sets
  end
end
