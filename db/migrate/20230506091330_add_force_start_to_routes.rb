class AddForceStartToRoutes < ActiveRecord::Migration
  def change
    add_column :routes, :force_start, :boolean
  end
end
