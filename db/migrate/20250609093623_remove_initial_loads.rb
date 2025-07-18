class RemoveInitialLoads < ActiveRecord::Migration[6.1]
  def up
    remove_column :deliverable_units, :default_initial_load
    remove_column :vehicles, :capacities_initial_loads
  end

  def down
    add_column :deliverable_units, :default_initial_load, :float
    add_column :vehicles, :capacities_initial_loads, :hstore
  end
end
