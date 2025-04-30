class AddRouteDeparture < ActiveRecord::Migration[6.1]
  def change
    add_column :routes, :departure, :integer
  end
end
