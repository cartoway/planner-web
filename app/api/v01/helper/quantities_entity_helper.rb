module QuantitiesEntityHelper
  def convert_pickups_deliveries_to_quantities(pickups, deliveries)
    quantities = {}
    pickups&.each { |du_id, value|
      next if value.nil?

      if quantities.key?(du_id)
        quantities[du_id][:quantity] += -value
        quantities[du_id][:pickup] += value
      else
        quantities[du_id] = { deliverable_unit_id: du_id, quantity: -value, pickup: value, delivery: 0 }
      end
    }
    deliveries&.each { |du_id, value|
      next if value.nil?

      if quantities.key?(du_id)
        quantities[du_id][:quantity] += value
        quantities[du_id][:delivery] += value
      else
        quantities[du_id] = { deliverable_unit_id: du_id, quantity: value, pickup: 0, delivery: value }
      end
    }
    quantities.values
  end
end
