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
class V01::Entities::DeliverableUnit < Grape::Entity
  def self.entity_name
    'V01_DeliverableUnit'
  end

  expose(:id, documentation: { type: Integer, desc: 'Internal identifier.', example: 3 })
  expose(:label, documentation: { type: String, desc: 'Display name of the unit (pallets, kg, …).', example: 'Pallet' })
  expose(:ref, documentation: { type: String, desc: 'External unique reference.', example: 'PAL' })
  expose(:icon, documentation: { type: String, desc: "Icon name from font-awesome. Default: #{::DeliverableUnit::ICON_DEFAULT}." })
  expose(:default_quantity, documentation: { type: Float, desc: 'Deprecated signed quantity (delivery minus pickup) when a single unit is used.' }) { |m| (m.default_delivery || 0) - (m.default_pickup || 0) }
  expose(:default_pickup, documentation: { type: Float, desc: 'Default pickup quantity applied to visits that omit quantities for this unit.', example: 0.0 })
  expose(:default_delivery, documentation: { type: Float, desc: 'Default delivery quantity applied to visits that omit quantities for this unit.', example: 1.0 })
  expose(:default_capacity, documentation: { type: Float, desc: 'Default vehicle capacity for this unit when the vehicle has no override.', example: 48.0 })
  expose(:optimization_overload_multiplier, documentation: { type: Integer, desc: 'Penalty multiplier when vehicle capacity is exceeded during optimization. 0 ignores overload.' })
end
