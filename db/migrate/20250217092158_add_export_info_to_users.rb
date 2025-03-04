class AddExportInfoToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :exportable_columns, :jsonb, default: {}
  end
end
