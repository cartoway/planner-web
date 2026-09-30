# frozen_string_literal: true

class RenamePlanningDateOffsetToOperationDateOffset < ActiveRecord::Migration[6.1]
  def change
    rename_column :customers, :planning_date_offset, :operation_date_offset
  end
end
