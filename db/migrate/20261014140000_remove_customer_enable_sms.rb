# frozen_string_literal: true

class RemoveCustomerEnableSms < ActiveRecord::Migration[6.1]
  def up
    if column_exists?(:customers, :enable_sms)
      execute <<~SQL.squish
        UPDATE customers
        SET enable_sms_driver = true
        WHERE enable_sms = true
      SQL
      remove_column :customers, :enable_sms
    end
  end

  def down
    add_column :customers, :enable_sms, :boolean, default: false, null: false unless column_exists?(:customers, :enable_sms)
    execute <<~SQL.squish
      UPDATE customers
      SET enable_sms = enable_sms_driver
    SQL
  end
end
