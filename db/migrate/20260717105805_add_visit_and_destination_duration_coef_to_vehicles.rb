# frozen_string_literal: true

class AddVisitAndDestinationDurationCoefToVehicles < ActiveRecord::Migration[6.1]
  def up
    add_column :vehicles, :visit_duration_coef, :float unless column_exists?(:vehicles, :visit_duration_coef)
    add_column :vehicles, :destination_duration_coef, :float unless column_exists?(:vehicles, :destination_duration_coef)
  end

  def down
    remove_column :vehicles, :visit_duration_coef if column_exists?(:vehicles, :visit_duration_coef)
    remove_column :vehicles, :destination_duration_coef if column_exists?(:vehicles, :destination_duration_coef)
  end
end
