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
class V01::Entities::VehicleStore < V01::Entities::Store
  def self.entity_name
    'V01_VehicleStore'
  end

  expose(:emission, documentation: { type: Integer })
  expose(:consumption, documentation: { type: Integer })
  expose(:fuel_type, documentation: { type: String })
  expose(:capacity, documentation: { type: Integer, desc: 'Deprecated, use capacities instead.' }) { |m|
    if m.capacities && m.customer.deliverable_units.size == 1
      capacities = m.capacities.values
      capacities[0] if capacities.size == 1
    end
  }
  expose(:capacity_unit, documentation: { type: String, desc: 'Deprecated, use capacities and deliverable_unit entity instead.' }) { |m|
    if m.capacities && m.customer.deliverable_units.size == 1
      deliverable_unit_ids = m.capacities.keys
      m.customer.deliverable_units[0].label if deliverable_unit_ids.size == 1
    end
  }
  expose(:capacities, using: V01::Entities::DeliverableUnitQuantity, documentation: { type: V01::Entities::DeliverableUnitQuantity, is_array: true, param_type: 'form' }) { |m|
    m.capacities ? m.capacities.to_a.collect{ |a| {deliverable_unit_id: a[0], quantity: a[1]} } : []
  }
  expose(:router_id, documentation: { type: Integer })
  expose(:router_dimension, documentation: { type: String, values: ::Router::DIMENSION.keys })
  expose(:speed_multiplicator, documentation: { type: Float, desc: 'Deprecated, use speed_multiplier instead.' }) { |m| m.speed_multiplier }
  expose(:speed_multiplier, documentation: { type: Float })
end
