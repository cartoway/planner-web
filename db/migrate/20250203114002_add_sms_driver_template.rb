class AddSmsDriverTemplate < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :sms_driver_template, :string
  end
end
