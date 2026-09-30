# frozen_string_literal: true

class AddProofRetentionDaysToCustomers < ActiveRecord::Migration[6.1]
  def change
    add_column :customers, :proof_retention_days, :integer, null: false, default: 365
  end
end
