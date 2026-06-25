# frozen_string_literal: true

class AddIndexToVehicleUsages < ActiveRecord::Migration[6.1]
  INDEX_NAME = 'index_vehicle_usages_on_vehicle_usage_set_id_and_index'

  def up
    add_column :vehicle_usages, :index, :integer, null: false, default: 0

    execute <<~SQL.squish
      UPDATE vehicle_usages
      SET index = sub.row_index
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY vehicle_usage_set_id ORDER BY id) - 1 AS row_index
        FROM vehicle_usages
      ) AS sub
      WHERE vehicle_usages.id = sub.id
    SQL

    add_index :vehicle_usages, [:vehicle_usage_set_id, :index], unique: true, name: INDEX_NAME
  end

  def down
    remove_index :vehicle_usages, name: INDEX_NAME
    remove_column :vehicle_usages, :index
  end
end
