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
class V01::Entities::Zone < Grape::Entity
  def self.entity_name
    'V01_Zone'
  end

  expose(:id, documentation: { type: Integer, desc: 'Internal identifier.', example: 9 })
  expose(:name, documentation: { type: String, desc: 'Display name.', example: 'North sector' })
  expose(:vehicle_id, documentation: { type: Integer, desc: 'Vehicle this zone is assigned to. Applying the zoning sends stops inside the polygon to that vehicle route.', example: 2 })
  expose(:polygon, documentation: { type: String, desc: 'GeoJSON Feature (Polygon or MultiPolygon) describing the area.' })
  expose(:speed_multiplicator, documentation: { hidden: true, deprecated: true, type: Float, desc: 'Deprecated, use speed_multiplier instead.' }) { |m| m.speed_multiplier }
  expose(:speed_multiplier, documentation: { type: Float, desc: 'Speed multiplier for this area (1 is default). Taken into account only for routers which support avoid_zones or speed_zones.', example: 1.0 })
end
