# frozen_string_literal: true

class AllowNullStatusOnOperationStopStatusEvents < ActiveRecord::Migration[6.1]
  def change
    change_column_null :operation_stop_status_events, :status, true
  end
end
