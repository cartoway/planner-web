class AddLoadAndLoadingsToRoutes < ActiveRecord::Migration[6.1]
  def up
    add_column :routes, :loadings, :hstore
    add_column :stops, :loads, :hstore
  end

  def down
    remove_column :routes, :loadings
    remove_column :stops, :loads
  end
end
