class AddCustomerEnableSmsIntransit < ActiveRecord::Migration[6.1]
  def up
    add_column :customers, :enable_sms_intransit, :boolean, default: false
  end

  def down
    remove_column :customers, :enable_sms_intransit
  end
end
