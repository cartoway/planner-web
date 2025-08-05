# Copyright © Mapotempo, 2018
#
# This file is part of Mapotempo.
#
# Mapotempo is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Mapotempo is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Mapotempo. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#
class VisitQuantities
  def self.normalize(visit, vehicle, options = {})
    options[:with_default] = true unless options.key? :with_default
    pickups = visit.send(options[:with_default] ? :default_pickups : :pickups)
    deliveries = visit.send(options[:with_default] ? :default_deliveries : :deliveries)
    visit.destination.customer.deliverable_units.map{ |du|
      next if !options[:with_nil] && !(pickups[du.id] && pickups[du.id] > 0) && !(deliveries[du.id] && deliveries[du.id] > 0)

      delivery = deliveries[du.id] || 0
      pickup = pickups[du.id] || 0
      quantity = delivery - pickup
      q = ' '
      if pickup > 0
        q += '+'
        q += number_with_precision(pickups[du.id], precision: 2, delimiter: I18n.t('number.format.delimiter'), strip_insignificant_zeros: true).to_s
        q += '/' + number_with_precision(vehicle.default_capacities[du.id], precision: 2, delimiter: I18n.t('number.format.delimiter'), strip_insignificant_zeros: true).to_s if vehicle && vehicle.default_capacities[du.id]
        q += ' & ' if delivery > 0
      end

      if delivery > 0
        q += '-' if pickup > 0
        q += number_with_precision(deliveries[du.id], precision: 2, delimiter: I18n.t('number.format.delimiter'), strip_insignificant_zeros: true).to_s
        q += '/' + number_with_precision(vehicle.default_capacities[du.id], precision: 2, delimiter: I18n.t('number.format.delimiter'), strip_insignificant_zeros: true).to_s if vehicle && vehicle.default_capacities[du.id]
      end

      q += "\u202F" + du.label if du.label
      {
        deliverable_unit_id: du.id,
        quantity: quantity, # FLOAT
        pickup: pickups[du.id],
        delivery: deliveries[du.id],
        label: du.label,
        unit_icon: du.default_icon,
        quantity_formatted: q # STRING
      }
    }.compact
  end
end
