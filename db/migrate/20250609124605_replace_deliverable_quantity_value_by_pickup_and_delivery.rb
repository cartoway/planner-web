class ReplaceDeliverableQuantityValueByPickupAndDelivery < ActiveRecord::Migration[6.1]
  def up
    add_column :deliverable_units, :default_pickup, :float
    add_column :deliverable_units, :default_delivery, :float

    add_column :visits, :pickups, :hstore
    add_column :visits, :deliveries, :hstore

    add_column :routes, :pickups, :hstore
    add_column :routes, :deliveries, :hstore

    # transfer default_quantity to default_pickup and default_delivery
    # we assume positive values are deliveries and negative values are pickups
    DeliverableUnit.all.find_each do |deliverable_unit|
      next if deliverable_unit.default_quantity.nil?

      if deliverable_unit.default_quantity < 0
        deliverable_unit.update(default_pickup: -deliverable_unit.default_quantity)
      else
        deliverable_unit.update(default_delivery: deliverable_unit.default_quantity)
      end
    end

    # transfer quantities to pickups and deliveries
    Visit.all.find_each do |visit|
      visit_pickups = {}
      visit_deliveries = {}
      visit.quantities&.each do |deliverable_unit_id, quantity|
        next if quantity.nil?

        if quantity.to_f < 0
          visit_pickups[deliverable_unit_id] = quantity.to_f.abs
        else
          visit_deliveries[deliverable_unit_id] = quantity.to_f
        end
      end
      visit.update(pickups: visit_pickups, deliveries: visit_deliveries)
    end

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

    # transfer pickups and deliveries to quantities
    DeliverableUnit.all.find_each do |deliverable_unit|
      next if deliverable_unit.default_delivery.nil? && deliverable_unit.default_pickup.nil?

      deliverable_unit.update(default_quantity: (deliverable_unit.default_delivery || 0) - (deliverable_unit.default_pickup || 0))
    end

    # transfer pickups and deliveries to quantities
    Visit.all.find_each do |visit|
      visit.pickups&.each do |deliverable_unit_id, quantity|
        next if quantity.nil?

        visit.quantities[deliverable_unit_id] = -quantity
      end
      visit.deliveries&.each do |deliverable_unit_id, quantity|
        next if quantity.nil?

        visit.quantities[deliverable_unit_id] = quantity
      end
    end

    Route.all.find_each do |route|
      quantities = {}
      route.pickups.each do |deliverable_unit_id, quantity|
        next if quantity.nil?

        quantities[deliverable_unit_id] = 0 if quantities[deliverable_unit_id].nil?
        quantities[deliverable_unit_id] -= quantity
      end
      route.deliveries.each do |deliverable_unit_id, quantity|
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
