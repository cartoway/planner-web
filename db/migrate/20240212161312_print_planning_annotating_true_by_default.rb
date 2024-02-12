class PrintPlanningAnnotatingTrueByDefault < ActiveRecord::Migration
  def change
    change_column_default :customers, :print_planning_annotating, true
  end
end
