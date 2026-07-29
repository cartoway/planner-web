class AddResellerExtraDasboardUrl < ActiveRecord::Migration[6.1]
  def up
    add_column :resellers, :extra_dashboard_url, :string
  end

  def down
    remove_column :resellers, :extra_dashboard_url
  end
end
