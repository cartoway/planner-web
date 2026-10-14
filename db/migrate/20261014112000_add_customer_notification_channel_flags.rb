# frozen_string_literal: true

class AddCustomerNotificationChannelFlags < ActiveRecord::Migration[6.1]
  def up
    add_column :customers, :enable_email_driver, :boolean, default: true, null: false
    add_column :customers, :enable_sms_driver, :boolean, default: false, null: false
    add_column :customers, :enable_email_destination, :boolean, default: true, null: false
    add_column :customers, :enable_sms_destination, :boolean, default: false, null: false

    # Legacy enable_sms → driver SMS only
    execute <<~SQL.squish
      UPDATE customers
      SET enable_sms_driver = true
      WHERE enable_sms = true
    SQL
  end

  def down
    remove_column :customers, :enable_email_driver
    remove_column :customers, :enable_sms_driver
    remove_column :customers, :enable_email_destination
    remove_column :customers, :enable_sms_destination
  end
end
