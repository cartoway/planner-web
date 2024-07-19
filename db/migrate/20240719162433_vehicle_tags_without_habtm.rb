class VehicleTagsWithoutHabtm < ActiveRecord::Migration[6.1]
  def up
    rename_table :tags_vehicles, :tag_vehicles
    rename_table :tags_vehicle_usages, :tag_vehicle_usages

    add_timestamps :tag_vehicles, default: Time.zone.now
    add_timestamps :tag_vehicle_usages, default: Time.zone.now
  end

  def down
    remove_column :tag_vehicles, :created_at
    remove_column :tag_vehicles, :updated_at

    remove_column :tag_vehicle_usages, :created_at
    remove_column :tag_vehicle_usages, :updated_at

    rename_table :tag_vehicles, :tags_vehicles
    rename_table :tag_vehicle_usages, :tags_vehicle_usages
  end
end
