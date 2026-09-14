# Copyright © Mapotempo, 2014-2015
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
class V01::Entities::VehicleWithoutVehicleUsage < Grape::Entity
  def self.entity_name
    'V01_VehicleWithoutVehicleUsage'
  end

  expose(:id, documentation: { type: Integer, desc: 'Internal identifier.', example: 2 })
  expose(:ref, documentation: { type: String, desc: 'External unique reference. Use ref:VALUE in path/ids filters.', example: 'VEH-1' })
  expose(:name, documentation: { type: String, desc: 'Display name.', example: 'Truck 1' })
  expose(:contact_email, documentation: { type: String, desc: 'Driver device e-mail(s). Several addresses may be separated by spaces, commas or semicolons.' })
  expose(:phone_number, documentation: { type: String, desc: 'Driver phone number (SMS).' })
  expose(:emission, documentation: { type: Float, desc: 'CO2 emission factor used to compute route emission.' })
  expose(:consumption, documentation: { type: Float, desc: 'Fuel consumption factor used to compute route consumption.' })
  expose(:capacity, documentation: { hidden: true, deprecated: true, type: Integer, desc: 'Deprecated, use capacities instead.' }) { |m|
    if m.capacities && m.customer.deliverable_units.size == 1
      capacities = m.capacities.values
      capacities[0] if capacities.size == 1
    end
  }
  expose(:capacity_unit, documentation: { hidden: true, deprecated: true, type: String, desc: 'Deprecated, use capacities and deliverable_unit entity instead.' }) { |m|
    if m.capacities && m.customer.deliverable_units.size == 1
      deliverable_unit_ids = m.capacities.keys
      m.customer.deliverable_units[0].label if deliverable_unit_ids.size == 1
    end
  }
  expose(:capacities, using: V01::Entities::DeliverableUnitQuantity, documentation: { type: V01::Entities::DeliverableUnitQuantity, is_array: true, param_type: 'form', desc: 'Vehicle capacities per deliverable unit (quantity = max load).' }) { |m|
    m.capacities ? m.capacities.to_a.collect{ |a| {deliverable_unit_id: a[0], quantity: a[1]} } : []
  }
  expose(:color, documentation: { type: String, desc: 'Color code with #. For instance: #FF0000', example: '#FF0000' })
  expose(:fuel_type, documentation: { type: String, desc: 'Fuel type label (informational).' })
  expose(:router_id, documentation: { type: Integer, desc: 'Router used to compute this vehicle tracks. Falls back to customer router.' })
  expose(:router_dimension, documentation: { type: String, values: ::Router::DIMENSION.keys, desc: 'Optimize for time or distance.' })
  expose(:router_options, using: V01::Entities::RouterOptions, documentation: { type: V01::Entities::RouterOptions, desc: 'Truck constraints passed to the router (weight, height, toll, …).' })
  expose(:speed_multiplicator, documentation: { hidden: true, deprecated: true, type: Float, desc: 'Deprecated, use speed_multiplier instead.' }) { |m| m.speed_multiplier }
  expose(:speed_multiplier, documentation: { type: Float, desc: 'Speed multiplier applied to router times (1 is default).', example: 1.0 })
  expose(:max_distance, documentation: { type: Integer, desc: 'Maximum achievable distance in meters' })
  expose(:max_ride_distance, documentation: { type: Integer, desc: 'Maximum riding distance between two stops within a route in meters' })
  expose(:max_ride_duration, documentation: { type: DateTime, desc: 'Maximum riding time between two stops within a route' }) { |m| m.max_ride_duration_absolute_time_with_seconds }
  expose(:tag_ids, documentation: { type: Integer, is_array: true, desc: 'Skills: visit tags required on this vehicle. Visits with unmatched tags raise out_of_skill.' })
  # Devices
  # add auth for : orange_id, teksat_id, tomtom_id
  expose(:devices, documentation: { type: Hash, desc: 'Telematics device identifiers keyed by provider (when the customer option is enabled).' })
  expose(:custom_attributes_typed_hash, documentation: { type: Hash, desc: 'Additional typed properties defined on CustomAttribute for vehicles.' }, as: :custom_attributes)
end

class V01::Entities::Vehicle < V01::Entities::VehicleWithoutVehicleUsage
  def self.entity_name
    'V01_Vehicle'
  end

  expose(:vehicle_usages, using: V01::Entities::VehicleUsage, documentation: { type: V01::Entities::VehicleUsage, is_array: true, desc: 'Usages of this vehicle in each vehicle usage set.' })
end
