class AddForcePositionToVisits < ActiveRecord::Migration
  def up
    add_column :visits, :force_position, :integer, default: 0
    add_column :stops, :out_of_force_position, :boolean, default: false
  end

  def down
    remove_column :visits, :force_position
    remove_column :stops, :out_of_force_position
  end
end
