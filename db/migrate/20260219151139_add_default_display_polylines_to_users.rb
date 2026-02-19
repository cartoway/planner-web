class AddDefaultDisplayPolylinesToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :default_display_polylines, :boolean, default: true, null: false
  end
end
