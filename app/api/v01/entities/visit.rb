# Copyright © Mapotempo, 2016
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
class V01::Entities::Visit < Grape::Entity
  def self.entity_name
    'V01_Visit'
  end

  expose(:id, documentation: { type: Integer })
  expose(:destination_id, documentation: { type: Integer })
  expose(:quantity, documentation: { type: Integer, desc: 'Deprecated, use quantities instead.' }) { |m|
    if m.quantities && m.destination.customer.deliverable_units.size == 1
      quantities = m.quantities.values
      quantities[0] if quantities.size == 1
    end
  }
  expose(:quantity_default, documentation: { type: Integer, desc: 'Deprecated, use quantities instead.' }) { |m|
    if m.quantities && m.destination.customer.deliverable_units.size == 1
      m.destination.customer.deliverable_units[0].default_quantity
    end
  }
  expose(:quantities, using: V01::Entities::DeliverableUnitQuantity, documentation: { type: V01::Entities::DeliverableUnitQuantity, is_array: true, param_type: 'form' }) { |m|
    m.destination.customer.deliverable_units.map{ |du|
      {
        deliverable_unit_id: du.id,
        quantity: m.quantities[du.id],
        operation: m.quantities_operations[du.id]
      } if m.quantities[du.id] || m.quantities_operations[du.id]
    }.compact
  }
  expose(:time_window_start_1, documentation: { type: DateTime }) { |m| m.time_window_start_1_absolute_time_with_seconds }
  expose(:time_window_end_1, documentation: { type: DateTime }) { |m| m.time_window_end_1_absolute_time_with_seconds }
  expose(:time_window_start_2, documentation: { type: DateTime }) { |m| m.time_window_start_2_absolute_time_with_seconds }
  expose(:time_window_end_2, documentation: { type: DateTime }) { |m| m.time_window_end_2_absolute_time_with_seconds }
  expose(:priority, documentation: { type: Integer, desc: 'Insertion priority when optimizing (-4 to 4, 0 if not defined).' })
  expose(:ref, documentation: { type: String })
  expose(:duration, documentation: { type: DateTime, desc: 'Visit duration.' }) { |m| m.take_over_absolute_time_with_seconds }
  expose(:take_over_default, documentation: { type: DateTime }) { |m| m.destination.customer && m.destination.customer.take_over_absolute_time_with_seconds }
  expose(:tag_ids, documentation: { type: Integer, is_array: true })
end
