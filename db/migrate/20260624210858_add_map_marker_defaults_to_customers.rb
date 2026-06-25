# frozen_string_literal: true

class AddMapMarkerDefaultsToCustomers < ActiveRecord::Migration[6.1]
  def change
    change_table :customers, bulk: true do |t|
      t.string :destination_icon
      t.string :destination_icon_size
      t.string :store_icon
      t.string :store_icon_size
      t.string :rest_icon
      t.string :rest_icon_size
    end
  end
end
