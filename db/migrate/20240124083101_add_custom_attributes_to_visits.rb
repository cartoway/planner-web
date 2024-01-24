class AddCustomAttributesToVisits < ActiveRecord::Migration
  def change
    add_column :visits, :custom_attributes, :jsonb, null: false, default: {}
  end
end
