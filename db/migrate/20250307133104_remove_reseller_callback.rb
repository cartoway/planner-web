class RemoveResellerCallback < ActiveRecord::Migration[6.1]
  def up
    remove_column :resellers, :external_callback_url
    remove_column :resellers, :external_callback_url_name
    remove_column :resellers, :enable_external_callback
  end

  def down
    add_column :resellers, :external_callback_url, :string
    add_column :resellers, :external_callback_url_name, :string
    add_column :resellers, :enable_external_callback, :boolean
  end
end
