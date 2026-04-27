# frozen_string_literal: true

class AddEnableStrictTimewindowsToCustomers < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :enable_strict_timewindows, :boolean, default: false, null: false
  end
end
