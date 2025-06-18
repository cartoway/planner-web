class ReplaceDeliverableQuantityValueByPickupAndDelivery < ActiveRecord::Migration[6.1]
  def up
    add_column :deliverable_units, :default_pickup, :float
    add_column :deliverable_units, :default_delivery, :float

    add_column :visits, :pickups, :jsonb, null: false, default: {}
    add_column :visits, :deliveries, :jsonb, null: false, default: {}

    add_column :routes, :pickups, :jsonb, null: false, default: {}
    add_column :routes, :deliveries, :jsonb, null: false, default: {}

    add_column :stops, :loads_jsonb, :jsonb, null: false, default: {}
    Stop.all.find_each do |stop|
      next unless stop.loads.present?
      stop.update_column(:loads_jsonb, stop.loads)
    end
    remove_column :stops, :loads
    rename_column :stops, :loads_jsonb, :loads

    add_column :vehicles, :capacities_jsonb, :jsonb, default: {}
    Vehicle.all.find_each do |vehicle|
      next unless vehicle.capacities.present?

      fixed_capacities = vehicle.capacities.transform_keys(&:to_i).transform_values do |value|
        case value
        when String
          value.to_f
        when Numeric
          value
        end
      end.compact

      vehicle.update_column(:capacities_jsonb, fixed_capacities)
    end
    remove_column :vehicles, :capacities
    rename_column :vehicles, :capacities_jsonb, :capacities

    # transfer default_quantity to default_pickup and default_delivery
    # we assume positive values are deliveries and negative values are pickups
    DeliverableUnit.where.not(default_quantity: nil)
                   .update_all("
                     default_pickup = CASE
                       WHEN default_quantity < 0 THEN -default_quantity
                       ELSE NULL
                     END,
                     default_delivery = CASE
                       WHEN default_quantity >= 0 THEN default_quantity
                       ELSE NULL
                     END
                   ")
    # transfer quantities to pickups and deliveries
    execute <<-SQL
      UPDATE visits
      SET
        pickups = COALESCE((
          SELECT jsonb_object_agg(
            key,
            ABS(value::float)
          )
          FROM each(quantities)
          WHERE value::float < 0
        ), '{}'::jsonb),
        deliveries = COALESCE((
          SELECT jsonb_object_agg(
            key,
            value::float
          )
          FROM each(quantities)
          WHERE value::float >= 0
        ), '{}'::jsonb)
      WHERE quantities IS NOT NULL;
    SQL

    Route.joins(planning: { customer: :deliverable_units }).update_all(outdated: true)

    remove_column :deliverable_units, :default_quantity
    remove_column :visits, :quantities
    remove_column :routes, :quantities
    remove_column :routes, :loadings
  end

  def down
    add_column :deliverable_units, :default_quantity, :float
    add_column :visits, :quantities, :hstore
    add_column :routes, :loadings, :hstore
    add_column :routes, :quantities, :hstore

    add_column :stops, :loads_hstore, :hstore
    Stop.all.find_each do |stop|
      next unless stop.loads.present?
      stop.update_column(:loads_hstore, stop.loads)
    end
    remove_column :stops, :loads
    rename_column :stops, :loads_hstore, :loads

    add_column :vehicles, :capacities_hstore, :hstore
    Vehicle.all.find_each do |vehicle|
      next unless vehicle.capacities.present?
      vehicle.update_column(:capacities_hstore, vehicle.capacities)
    end
    remove_column :vehicles, :capacities
    rename_column :vehicles, :capacities_hstore, :capacities

    # transfer pickups and deliveries to quantities
    DeliverableUnit.all.find_each do |deliverable_unit|
      next if deliverable_unit.default_delivery.nil? && deliverable_unit.default_pickup.nil?

      deliverable_unit.update(default_quantity: (deliverable_unit.default_delivery || 0) - (deliverable_unit.default_pickup || 0))
    end

    # transfer pickups and deliveries to quantities
    execute <<-SQL
      UPDATE visits
      SET quantities = (
        SELECT hstore(
          array_agg(key),
          array_agg(value::text)
        )
        FROM (
          SELECT key, -value::float as value
          FROM jsonb_each_text(pickups)
          WHERE pickups IS NOT NULL AND jsonb_typeof(pickups) = 'object'
          UNION ALL
          SELECT key, value::float as value
          FROM jsonb_each_text(deliveries)
          WHERE deliveries IS NOT NULL AND jsonb_typeof(deliveries) = 'object'
        ) combined
      )
      WHERE (pickups IS NOT NULL AND jsonb_typeof(pickups) = 'object')
        OR (deliveries IS NOT NULL AND jsonb_typeof(deliveries) = 'object');
    SQL

    Route.all.find_each do |route|
      quantities = {}
      route.pickups&.each do |deliverable_unit_id, quantity|
        next if quantity.nil?

        quantities[deliverable_unit_id] = 0 if quantities[deliverable_unit_id].nil?
        quantities[deliverable_unit_id] -= quantity
      end
      route.deliveries&.each do |deliverable_unit_id, quantity|
        next if quantity.nil?

        quantities[deliverable_unit_id] = 0 if quantities[deliverable_unit_id].nil?
        quantities[deliverable_unit_id] += quantity
      end
      route.update(quantities: quantities)
    end

    remove_column :deliverable_units, :default_pickup
    remove_column :deliverable_units, :default_delivery
    remove_column :visits, :pickups
    remove_column :visits, :deliveries
    remove_column :routes, :pickups
    remove_column :routes, :deliveries
  end
end
