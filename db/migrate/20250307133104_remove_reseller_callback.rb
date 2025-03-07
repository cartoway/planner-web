class RemoveResellerCallback < ActiveRecord::Migration[6.1]
  def change
    remove_column :resellers, :external_callback_url
    remove_column :resellers, :external_callback_url_name
    remove_column :resellers, :enable_external_callback
  end
end
