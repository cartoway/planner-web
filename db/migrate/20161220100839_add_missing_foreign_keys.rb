class AddMissingForeignKeys < ActiveRecord::Migration
  def change
  	 add_foreign_key :customers, :resellers

  	 add_foreign_key :deliverable_units, :customers

  	 add_foreign_key :layers_profiles, :profiles
  	 add_foreign_key :layers_profiles, :layers

  	 add_foreign_key :profiles_routers, :profiles
  	 add_foreign_key :profiles_routers, :routers
  
  	 add_foreign_key :users, :resellers
  end
end
