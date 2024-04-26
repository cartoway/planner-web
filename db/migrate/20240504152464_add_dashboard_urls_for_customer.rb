class AddDashboardUrlsForCustomer < ActiveRecord::Migration
  def change
    add_column :resellers, :customer_dashboard_url, :string
  end
end
