# frozen_string_literal: true

class ReplaceSmsFromCustomerNameWithSmsSenderName < ActiveRecord::Migration[6.1]
  def up
    add_column :customers, :sms_sender_name, :string unless column_exists?(:customers, :sms_sender_name)
    remove_column :customers, :sms_from_customer_name if column_exists?(:customers, :sms_from_customer_name)
  end

  def down
    add_column :customers, :sms_from_customer_name, :boolean, default: false, null: false unless column_exists?(:customers, :sms_from_customer_name)
    remove_column :customers, :sms_sender_name if column_exists?(:customers, :sms_sender_name)
  end
end
