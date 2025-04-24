class AddDestinationDuration < ActiveRecord::Migration[6.1]
  def change
    add_column :destinations, :duration, :integer
    add_column :customers, :destination_duration, :integer
  end
end
