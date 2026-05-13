# frozen_string_literal: true

class AddFilterPlanningRouteDataToUsers < ActiveRecord::Migration[6.1]
  def up
    add_column :users, :filter_planning_route_data, :boolean, null: false, default: false
  end

  def down
    remove_column :users, :filter_planning_route_data
  end
end
