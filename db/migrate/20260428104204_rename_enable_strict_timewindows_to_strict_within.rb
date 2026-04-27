# frozen_string_literal: true

class RenameEnableStrictTimewindowsToStrictWithinTimewindows < ActiveRecord::Migration[6.1]
  def up
    return unless column_exists?(:customers, :enable_strict_timewindows)

    rename_column :customers, :enable_strict_timewindows, :enable_strict_within_timewindows
  end

  def down
    return unless column_exists?(:customers, :enable_strict_within_timewindows)

    rename_column :customers, :enable_strict_within_timewindows, :enable_strict_timewindows
  end
end
