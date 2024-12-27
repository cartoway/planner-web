class AddUniqueConstraintToVisits < ActiveRecord::Migration[6.1]
  def change
    add_index :visits, [:destination_id, :ref], unique: true
  end
end
