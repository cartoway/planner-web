# frozen_string_literal: true

class ChangeCustomersEnableStrictWithinTimewindowsDefault < ActiveRecord::Migration[6.1]
  def change
    change_column_default :customers, :enable_strict_within_timewindows, from: false, to: true
  end
end
