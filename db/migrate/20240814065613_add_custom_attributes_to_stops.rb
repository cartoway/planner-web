class AddCustomAttributesToStops < ActiveRecord::Migration[6.1]
  def change
    add_column :stops, :custom_attributes, :jsonb, null: false, default: {}
  end
end
