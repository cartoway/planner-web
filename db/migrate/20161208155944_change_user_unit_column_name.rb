class ChangeUserUnitColumnName < ActiveRecord::Migration
  def change
  	 rename_column :users, :prefered_unity, :prefered_unit
  end
end
