class AddExportInfoToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :export_settings, :jsonb, default: {}
  end
end
