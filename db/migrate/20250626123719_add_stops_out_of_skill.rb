class AddStopsOutOfSkill < ActiveRecord::Migration[6.1]
  def up
    add_column :stops, :out_of_skill, :boolean
  end

  def down
    remove_column :stops, :out_of_skill
  end
end
