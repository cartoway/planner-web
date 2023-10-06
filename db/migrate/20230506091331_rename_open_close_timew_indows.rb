class RenameOpenCloseTimeWondows < ActiveRecord::Migration
  def change
    rename_column :visits, :open1, :time_window_start_1
    rename_column :visits, :close1, :time_window_end_1
    rename_column :visits, :open2, :time_window_start_2
    rename_column :visits, :close2, :time_window_end_2
    rename_column :visits, :close2, :time_window_end_2
    rename_column :vehicle_usage_sets, :open, :time_window_start
    rename_column :vehicle_usage_sets, :close, :time_window_end
    rename_column :vehicle_usages, :open, :time_window_start
    rename_column :vehicle_usages, :close, :time_window_end
  end
end
