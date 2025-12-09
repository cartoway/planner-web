class AddHiddenAndColorToRouteData < ActiveRecord::Migration[6.1]
  def change
    add_column :route_data, :hidden, :boolean, default: false, null: false
    add_column :route_data, :color, :string
  end
end
