class AddUniqueIndexToTagObjects < ActiveRecord::Migration[6.1]
  def up
    remove_duplicates(:tag_destinations, [:tag_id, :destination_id])
    remove_duplicates(:tag_plannings, [:tag_id, :planning_id])
    remove_duplicates(:tag_vehicles, [:tag_id, :vehicle_id])
    remove_duplicates(:tag_vehicle_usages, [:tag_id, :vehicle_usage_id])
    remove_duplicates(:tag_visits, [:tag_id, :visit_id])

    add_column :tag_destinations, :id, :primary_key
    add_column :tag_plannings, :id, :primary_key
    add_column :tag_vehicles, :id, :primary_key
    add_column :tag_vehicle_usages, :id, :primary_key
    add_column :tag_visits, :id, :primary_key

    add_index :tag_destinations, [:tag_id, :destination_id], unique: true
    add_index :tag_plannings, [:tag_id, :planning_id], unique: true
    add_index :tag_vehicles, [:tag_id, :vehicle_id], unique: true
    add_index :tag_vehicle_usages, [:tag_id, :vehicle_usage_id], unique: true
    add_index :tag_visits, [:tag_id, :visit_id], unique: true
  end

  def down
    remove_index :tag_destinations, [:tag_id, :destination_id]
    remove_index :tag_plannings, [:tag_id, :planning_id]
    remove_index :tag_vehicles, [:tag_id, :vehicle_id]
    remove_index :tag_vehicle_usages, [:tag_id, :vehicle_usage_id]
    remove_index :tag_visits, [:tag_id, :visit_id]

    remove_column :tag_destinations, :id
    remove_column :tag_plannings, :id
    remove_column :tag_vehicles, :id
    remove_column :tag_vehicle_usages, :id
    remove_column :tag_visits, :id
  end

  private

  def remove_duplicates(table, columns)
    execute <<-SQL
      DELETE FROM #{table}
      WHERE ctid NOT IN (
        SELECT MIN(ctid)
        FROM #{table}
        GROUP BY #{columns.join(', ')}
      )
    SQL
  end
end
