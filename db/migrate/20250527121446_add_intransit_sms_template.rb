class AddIntransitSmsTemplate < ActiveRecord::Migration[6.1]
  def up
    add_column :customers, :sms_intransit_template, :string
  end

  def down
    remove_column :customers, :sms_intransit_template
  end
end
