# frozen_string_literal: true

# Tracking tokens must outlive destination/planning rows (same snapshot model as OperationStop).
class DecoupleDeliveryTrackingDestinationFk < ActiveRecord::Migration[6.1]
  def up
    return unless foreign_key_exists?(:operation_delivery_trackings, :destinations)

    remove_foreign_key :operation_delivery_trackings, :destinations
  end

  def down
    return if foreign_key_exists?(:operation_delivery_trackings, :destinations)
    return unless table_exists?(:operation_delivery_trackings)

    add_foreign_key :operation_delivery_trackings, :destinations, on_delete: :cascade
  end
end
