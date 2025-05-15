class StopQuantities
  def self.normalize(stop, vehicle, options = {})
    options[:with_default] = true unless options.key? :with_default
    quantities = stop.visit.send(options[:with_default] ? :default_quantities : :quantities)
    loads = stop.loads
    stop.visit.destination.customer.deliverable_units.map{ |du|
      next unless options[:with_nil] || quantities && (quantities[du.id] && quantities[du.id] != 0 || stop.visit.quantities_operations[du.id])

      q = number_with_precision(loads[du.id], precision: 2, delimiter: I18n.t('number.format.delimiter'), strip_insignificant_zeros: true).to_s
      q += '/' + number_with_precision(vehicle.default_capacities[du.id], precision: 2, delimiter: I18n.t('number.format.delimiter'), strip_insignificant_zeros: true).to_s if vehicle && vehicle.default_capacities[du.id]
      q += "\u202F" + du.label if du.label

      q += quantities[du.id] > 0 ? ' (+' : ' ('
      q += number_with_precision(quantities[du.id], precision: 2, delimiter: I18n.t('number.format.delimiter'), strip_insignificant_zeros: true).to_s
      q += ')'

      q = I18n.t("activerecord.attributes.deliverable_unit.operation_#{stop.visit.quantities_operations[du.id]}") + " (#{q})" if stop.visit.quantities_operations[du.id]
      {
        deliverable_unit_id: du.id,
        quantity: quantities[du.id], # FLOAT
        label: du.label,
        unit_icon: du.default_icon,
        quantity_formatted: q # STRING
      }
    }.compact
  end
end
