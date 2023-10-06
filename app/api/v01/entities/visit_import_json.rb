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
class V01::Entities::VisitImportJson < V01::Entities::Visit
  def self.entity_name
    'V01_VisitImportJson'
  end

  unexpose(:destination_id)
  unexpose(:duration_default)
  expose(:route, documentation: { type: String, desc: 'Route reference. If route reference is specified, a new planning will be created with a route using the specified reference' })
  expose(:ref_vehicle, documentation: { type: String, desc: 'Vehicle reference. If vehicle reference is specified, a new planning will be created with a route using the vehicle with specified reference' })
  expose(:active, documentation: { type: 'Boolean', desc: 'In order to specify is stop is active in planning or not' })
end
