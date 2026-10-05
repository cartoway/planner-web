# frozen_string_literal: true

class RenameEnableStopStatusToEnableProofs < ActiveRecord::Migration[6.1]
  def change
    rename_column :customers, :enable_stop_status, :enable_proofs
  end
end
