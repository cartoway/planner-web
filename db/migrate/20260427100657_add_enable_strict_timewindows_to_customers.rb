# frozen_string_literal: true

class AddEnableStrictWithinTimewindowsToCustomers < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :enable_strict_within_timewindows, :boolean, default: false, null: false
  end
end
