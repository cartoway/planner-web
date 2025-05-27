class AddResellerPlanningDashboardUrl < ActiveRecord::Migration[6.1]
  def up
    add_column :resellers, :planning_dashboard_url, :string
  end

  def down
    remove_column :resellers, :planning_dashboard_url
  end
end
