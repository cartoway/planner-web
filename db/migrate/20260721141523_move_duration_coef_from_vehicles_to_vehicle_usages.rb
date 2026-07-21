# frozen_string_literal: true

class MoveDurationCoefFromVehiclesToVehicleUsages < ActiveRecord::Migration[6.1]
  def up
    add_column :vehicle_usage_sets, :visit_duration_coef, :float unless column_exists?(:vehicle_usage_sets, :visit_duration_coef)
    add_column :vehicle_usage_sets, :destination_duration_coef, :float unless column_exists?(:vehicle_usage_sets, :destination_duration_coef)
    add_column :vehicle_usages, :visit_duration_coef, :float unless column_exists?(:vehicle_usages, :visit_duration_coef)
    add_column :vehicle_usages, :destination_duration_coef, :float unless column_exists?(:vehicle_usages, :destination_duration_coef)

    if column_exists?(:vehicles, :visit_duration_coef)
      execute <<-SQL.squish
        UPDATE vehicle_usages
        SET visit_duration_coef = vehicles.visit_duration_coef,
            destination_duration_coef = vehicles.destination_duration_coef
        FROM vehicles
        WHERE vehicle_usages.vehicle_id = vehicles.id
          AND (vehicles.visit_duration_coef IS NOT NULL OR vehicles.destination_duration_coef IS NOT NULL)
      SQL

      remove_column :vehicles, :visit_duration_coef
      remove_column :vehicles, :destination_duration_coef
    end
  end

  def down
    add_column :vehicles, :visit_duration_coef, :float unless column_exists?(:vehicles, :visit_duration_coef)
    add_column :vehicles, :destination_duration_coef, :float unless column_exists?(:vehicles, :destination_duration_coef)

    if column_exists?(:vehicle_usages, :visit_duration_coef)
      execute <<-SQL.squish
        UPDATE vehicles
        SET visit_duration_coef = subquery.visit_duration_coef,
            destination_duration_coef = subquery.destination_duration_coef
        FROM (
          SELECT DISTINCT ON (vehicle_id)
            vehicle_id,
            visit_duration_coef,
            destination_duration_coef
          FROM vehicle_usages
          WHERE visit_duration_coef IS NOT NULL OR destination_duration_coef IS NOT NULL
          ORDER BY vehicle_id, id
        ) AS subquery
        WHERE vehicles.id = subquery.vehicle_id
      SQL

      remove_column :vehicle_usages, :visit_duration_coef
      remove_column :vehicle_usages, :destination_duration_coef
    end

    remove_column :vehicle_usage_sets, :visit_duration_coef if column_exists?(:vehicle_usage_sets, :visit_duration_coef)
    remove_column :vehicle_usage_sets, :destination_duration_coef if column_exists?(:vehicle_usage_sets, :destination_duration_coef)
  end
end
