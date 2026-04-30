# frozen_string_literal: true

class AddStopsPreloadLimitToCustomers < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :stops_preload_limit, :integer, null: false, default: 1000
  end
end
