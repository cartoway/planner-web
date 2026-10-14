# frozen_string_literal: true

# Renames channel flags when the first notification migration already ran with *_recipient names.
class RenameCustomerNotificationRecipientToDestination < ActiveRecord::Migration[6.1]
  def up
    if column_exists?(:customers, :enable_email_recipient)
      rename_column :customers, :enable_email_recipient, :enable_email_destination
    end
    if column_exists?(:customers, :enable_sms_recipient)
      rename_column :customers, :enable_sms_recipient, :enable_sms_destination
    end
  end

  def down
    if column_exists?(:customers, :enable_email_destination)
      rename_column :customers, :enable_email_destination, :enable_email_recipient
    end
    if column_exists?(:customers, :enable_sms_destination)
      rename_column :customers, :enable_sms_destination, :enable_sms_recipient
    end
  end
end
