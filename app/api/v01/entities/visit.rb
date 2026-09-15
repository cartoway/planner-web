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

  expose(:id, documentation: { type: Integer, desc: 'Internal identifier.', example: 101 })
  expose(:destination_id, documentation: { type: Integer, desc: 'Parent destination id.', example: 42 })
  expose(:quantity, documentation: { hidden: true, deprecated: true, type: Integer, desc: 'Deprecated, use quantities instead.' }) { |m|
    quantities = convert_pickups_deliveries_to_quantities(m.pickups, m.deliveries)
    if quantities.size == 1 && m.destination.customer.deliverable_units.size == 1
      quantities[0]
    end
  }
  expose(:quantity_default, documentation: { hidden: true, deprecated: true, type: Integer, desc: 'Deprecated, use quantities instead.' }) { |m|
    quantities = convert_pickups_deliveries_to_quantities(m.pickups, m.deliveries)
    if quantities.size == 1 && m.destination.customer.deliverable_units.size == 1
      quantities[0]
    end
  }
  expose(:quantities, using: V01::Entities::DeliverableUnitQuantity, documentation: { type: V01::Entities::DeliverableUnitQuantity, is_array: true, param_type: 'form', desc: 'Pickup/delivery quantities per deliverable unit. Prefer pickup and delivery over deprecated quantity.' }) { |m|
    convert_pickups_deliveries_to_quantities(m.pickups, m.deliveries)
  }
  expose(:time_window_start_1, documentation: { type: DateTime, desc: 'Start of the first time window (HH:MM or HH:MM:SS on input).' }) { |m| m.time_window_start_1_absolute_time_with_seconds }
  expose(:time_window_end_1, documentation: { type: DateTime, desc: 'End of the first time window.' }) { |m| m.time_window_end_1_absolute_time_with_seconds }
  expose(:time_window_start_2, documentation: { type: DateTime, desc: 'Start of the optional second time window.' }) { |m| m.time_window_start_2_absolute_time_with_seconds }
  expose(:time_window_end_2, documentation: { type: DateTime, desc: 'End of the optional second time window.' }) { |m| m.time_window_end_2_absolute_time_with_seconds }
  expose(:priority, documentation: { type: Integer, desc: 'Insertion priority when optimizing (-4 to 4, 0 if not defined). Higher is served first.', example: 0 })
  expose(:ref, documentation: { type: String, desc: 'External reference unique among visits of the same destination. Upsert key on import.', example: 'V1' })
  expose(:duration, documentation: { type: DateTime, desc: 'Service duration of this visit (HH:MM or HH:MM:SS on input).' }) { |m| m.duration_absolute_time_with_seconds }
  expose(:duration_default, documentation: { type: DateTime, desc: 'Customer default visit duration, used when duration is not set on the visit.' }) { |m| m.destination.customer && m.destination.customer.visit_duration_absolute_time_with_seconds }
  expose(:tag_ids, documentation: { type: Integer, is_array: true, desc: 'Tag ids. A planning with tag_ids only includes visits matching tag_operation (and/or).', example: [1] })
  expose(:force_position, documentation: { type: String, values: %w[neutral always_first never_first always_final], desc: 'Forced position among visits that share the same constraint on the route: always_first, never_first, always_final, or neutral (default).', example: 'neutral' })
  expose(:custom_attributes_typed_hash, documentation: { type: Hash, desc: 'Additional typed properties defined on CustomAttribute for visits.' }, as: :custom_attributes)

  # Deprecated fields
  expose(:open1, documentation: { hidden: true, type: DateTime, desc: 'Deprecated, use `time_window_start_1` instead' }) { |m| m.time_window_start_1_absolute_time_with_seconds }
  expose(:close1, documentation: { hidden: true, type: DateTime, desc: 'Deprecated, use `time_window_end_1` instead.' }) { |m| m.time_window_end_1_absolute_time_with_seconds }
  expose(:open2, documentation: { hidden: true, type: DateTime, desc: 'Deprecated, use `time_window_start_2` instead' }) { |m| m.time_window_start_2_absolute_time_with_seconds }
  expose(:close2, documentation: { hidden: true, type: DateTime, desc: 'Deprecated, use `time_window_end_2` instead.' }) { |m| m.time_window_end_2_absolute_time_with_seconds }
end
