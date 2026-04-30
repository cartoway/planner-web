# frozen_string_literal: true

class AddSizeActiveDestinationsToRouteData < ActiveRecord::Migration[6.1]
  def change
    add_column :route_data, :size_active_destinations, :integer, null: false, default: 0
  end
end
