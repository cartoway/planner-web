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
class V01::Entities::Zoning < Grape::Entity
  def self.entity_name
    'V01_Zoning'
  end

  expose(:id, documentation: { type: Integer, desc: 'Internal identifier.', example: 5 })
  expose(:name, documentation: { type: String, desc: 'Display name.', example: 'City sectors' })
  expose(:zones, using: V01::Entities::Zone, documentation: { type: V01::Entities::Zone, is_array: true, desc: 'Zones (polygons) in this zoning, each optionally linked to a vehicle.' })
end
