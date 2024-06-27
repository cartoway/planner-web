class DefaultStopTypeAsStopVisit < ActiveRecord::Migration[5.2]
  def up
    change_column_default(:stops, :type, 'StopVisit')
  end

  def down
    change_column_default(:stops, :type, 'StopDestination')
  end
end
