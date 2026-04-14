# frozen_string_literal: true

# When true on a StopVisit, optimization keeps the visit on its current vehicle route (sticky_vehicle_ids).
class AddLockedToStops < ActiveRecord::Migration[6.1]
  def change
    add_column :stops, :locked, :boolean, null: false, default: false
  end
end
