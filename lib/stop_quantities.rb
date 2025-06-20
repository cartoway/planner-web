class StopQuantities
  def self.normalize(stop, vehicle, options = {})
    options[:with_default] = true unless options.key? :with_default
    options[:with_nil] = false unless options.key? :with_nil

    # Handle different stop types
    if stop.is_a?(StopVisit)
      normalize_stop_visit(stop, vehicle, options)
    elsif stop.is_a?(StopStore)
      normalize_stop_store(stop, vehicle, options)
    else
      []
    end
  end

  def self.normalize_stop_visit(stop, vehicle, options)
    pickups = stop.visit.send(options[:with_default] ? :default_pickups : :pickups)
    deliveries = stop.visit.send(options[:with_default] ? :default_deliveries : :deliveries)
    loads = stop.loads

    stop.visit.destination.customer.deliverable_units.map{ |du|
      next if !options[:with_nil] && (pickups[du.id] && pickups[du.id] == 0 && deliveries[du.id] && deliveries[du.id] == 0)

      delivery = stop.visit.default_deliveries[du.id] || 0
      pickup = pickups[du.id] || 0
      quantity = delivery - pickup
      q = number_with_precision(loads[du.id], precision: 2, delimiter: I18n.t('number.format.delimiter'), strip_insignificant_zeros: true).to_s
      q += '/' + number_with_precision(vehicle.default_capacities[du.id], precision: 2, delimiter: I18n.t('number.format.delimiter'), strip_insignificant_zeros: true).to_s if vehicle && vehicle.default_capacities[du.id]
      q += "\u202F" + du.label if du.label

      if pickup > 0
        q += ' (+'
        q += number_with_precision(pickup, precision: 2, delimiter: I18n.t('number.format.delimiter'), strip_insignificant_zeros: true).to_s
        q += ')'
      end

      if delivery > 0
        q += ' (-'
        q += number_with_precision(delivery, precision: 2, delimiter: I18n.t('number.format.delimiter'), strip_insignificant_zeros: true).to_s
        q += ')'
      end

      {
        deliverable_unit_id: du.id,
        quantity: quantity, # FLOAT
        pickup: stop.visit.default_pickups[du.id],
        delivery: stop.visit.default_deliveries[du.id],
        label: du.label,
        unit_icon: du.default_icon,
        quantity_formatted: q # STRING
      }
    }.compact
  end

  def self.normalize_stop_store(stop, vehicle, options)
    loads = stop.loads

    stop.route.planning.customer.deliverable_units.map{ |du|
      next if !options[:with_nil] && (loads[du.id].nil? || loads[du.id] == 0)

      quantity = loads[du.id] || 0
      q = number_with_precision(loads[du.id], precision: 2, delimiter: I18n.t('number.format.delimiter'), strip_insignificant_zeros: true).to_s
      q += '/' + number_with_precision(vehicle.default_capacities[du.id], precision: 2, delimiter: I18n.t('number.format.delimiter'), strip_insignificant_zeros: true).to_s if vehicle && vehicle.default_capacities[du.id]
      q += "\u202F" + du.label if du.label

      {
        deliverable_unit_id: du.id,
        quantity: quantity, # FLOAT
        pickup: nil,
        delivery: nil,
        label: du.label,
        unit_icon: du.default_icon,
        quantity_formatted: q # STRING
      }
    }.compact
  end
end
