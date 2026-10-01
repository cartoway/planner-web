# frozen_string_literal: true

class AddDeliveryTrackingEtaGapsToCustomers < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :delivery_tracking_eta_gap_before, :integer, null: false, default: 5
    add_column :customers, :delivery_tracking_eta_gap_after, :integer, null: false, default: 15
  end
end
