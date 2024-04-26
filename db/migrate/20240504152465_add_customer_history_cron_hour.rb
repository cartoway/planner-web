class AddCustomerHistoryCronHour < ActiveRecord::Migration
  def change
    add_column :customers, :history_cron_hour, :integer
  end
end
