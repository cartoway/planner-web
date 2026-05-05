class AddRestsDurationToRouteData < ActiveRecord::Migration[6.1]
  def change
    add_column :route_data, :rests_duration, :integer
  end
end
