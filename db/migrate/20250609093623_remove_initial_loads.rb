class RemoveInitialLoads < ActiveRecord::Migration[6.1]
  def change
    remove_column :deliverable_units, :default_initial_load
    remove_column :vehicles, :capacities_initial_loads
  end
end
