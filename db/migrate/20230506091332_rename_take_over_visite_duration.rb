class RenameTakeOverVisitesDuration < ActiveRecord::Migration
  def change
    rename_column :customers, :take_over, :visit_duration
    rename_column :visits, :take_over, :duration
  end
end
