# frozen_string_literal: true

# Mirror operation_routes transmit cursor so destination email/SMS modals
# can skip already-notified stops without scanning status events.
class AddLastSentToOperationStops < ActiveRecord::Migration[6.1]
  def change
    add_column :operation_stops, :last_sent_at, :datetime unless column_exists?(:operation_stops, :last_sent_at)
    add_column :operation_stops, :last_sent_to, :string unless column_exists?(:operation_stops, :last_sent_to)
  end
end
