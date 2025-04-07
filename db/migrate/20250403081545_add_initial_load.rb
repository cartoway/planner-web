class AddInitialLoad < ActiveRecord::Migration[6.1]
  def change
    add_column :deliverable_units, :default_initial_load, :float
    add_column :vehicles, :capacities_initial_loads, :hstore
  end
end
