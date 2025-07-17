module SharedHelper
  def aggregate_visit_quantities(customer, visits)
    deliverable_units = customer.deliverable_units

    quantities = {}
    deliverable_units.each do |unit|
      quantities[unit.id] = {
        id: unit.id,
        label: unit.label,
        icon: unit.default_icon,
        has_pickup: false,
        has_delivery: false,
        pickup: 0,
        delivery: 0
      }
    end

    return quantities if visits.blank?

    visits.each do |visit|
      next if !visit.is_a?(Visit)

      visit.default_pickups.each do |unit_id, quantity|
        quantities[unit_id][:pickup] += quantity.to_f
        quantities[unit_id][:has_pickup] ||= true if quantity.to_f > 0
      end

      visit.default_deliveries.each do |unit_id, quantity|
        quantities[unit_id][:delivery] += quantity.to_f
        quantities[unit_id][:has_delivery] ||= true if quantity.to_f > 0
      end
    end

    quantities
  end
end
