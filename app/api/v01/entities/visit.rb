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
  include QuantitiesEntityHelper

  def self.entity_name
    'V01_Visit'
  end

  expose(:id, documentation: { type: Integer })
  expose(:destination_id, documentation: { type: Integer })
  expose(:quantity, documentation: { type: Integer, desc: 'Deprecated, use quantities instead.' }) { |m|
    quantities = convert_pickups_deliveries_to_quantities(m.pickups, m.deliveries)
    if quantities && m.destination.customer.deliverable_units.size == 1
      quantities = quantities.values
      quantities[0] if quantities.size == 1
    end
  }
  expose(:quantity_default, documentation: { type: Integer, desc: 'Deprecated, use quantities instead.' }) { |m|
    quantities = convert_pickups_deliveries_to_quantities(m.pickups, m.deliveries)
    if quantities && m.destination.customer.deliverable_units.size == 1
      quantities = quantities.values
      quantities[0] if quantities.size == 1
    end
  }
  expose(:quantities, using: V01::Entities::DeliverableUnitQuantity, documentation: { type: V01::Entities::DeliverableUnitQuantity, is_array: true, param_type: 'form' }) { |m|
    convert_pickups_deliveries_to_quantities(m.pickups, m.deliveries)
  }
  expose(:time_window_start_1, documentation: { type: DateTime }) { |m| m.time_window_start_1_absolute_time_with_seconds }
  expose(:time_window_end_1, documentation: { type: DateTime }) { |m| m.time_window_end_1_absolute_time_with_seconds }
  expose(:time_window_start_2, documentation: { type: DateTime }) { |m| m.time_window_start_2_absolute_time_with_seconds }
  expose(:time_window_end_2, documentation: { type: DateTime }) { |m| m.time_window_end_2_absolute_time_with_seconds }
  expose(:priority, documentation: { type: Integer, desc: 'Insertion priority when optimizing (-4 to 4, 0 if not defined).' })
  expose(:ref, documentation: { type: String })
  expose(:duration, documentation: { type: DateTime, desc: 'Visit duration.' }) { |m| m.duration_absolute_time_with_seconds }
  expose(:duration_default, documentation: { type: DateTime }) { |m| m.destination.customer && m.destination.customer.visit_duration_absolute_time_with_seconds }
  expose(:tag_ids, documentation: { type: Integer, is_array: true })
  expose(:force_position, documentation: { type: String })
  expose(:custom_attributes_typed_hash, documentation: {type: Hash, desc: 'Additional properties'}, as: :custom_attributes)

  # Deprecated fields
  expose(:open1, documentation: { hidden: true, type: DateTime, desc: 'Deprecated, use `time_window_start_1` instead' }) { |m| m.time_window_start_1_absolute_time_with_seconds }
  expose(:close1, documentation: { hidden: true, type: DateTime, desc: 'Deprecated, use `time_window_end_1` instead.' }) { |m| m.time_window_end_1_absolute_time_with_seconds }
  expose(:open2, documentation: { hidden: true, type: DateTime, desc: 'Deprecated, use `time_window_start_2` instead' }) { |m| m.time_window_start_2_absolute_time_with_seconds }
  expose(:close2, documentation: { hidden: true, type: DateTime, desc: 'Deprecated, use `time_window_end_2` instead.' }) { |m| m.time_window_end_2_absolute_time_with_seconds }
end
