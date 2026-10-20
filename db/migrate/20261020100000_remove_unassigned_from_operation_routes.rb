# frozen_string_literal: true

class RemoveUnassignedFromOperationRoutes < ActiveRecord::Migration[6.1]
  def change
    remove_column :operation_routes, :unassigned, :boolean, null: false, default: false
  end
end
