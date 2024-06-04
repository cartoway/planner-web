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
class V01::Entities::RouteProperties < Grape::Entity
  def self.entity_name
    'V01_RouteProperties'
  end

  expose(:id, documentation: { type: Integer })
  expose(:vehicle_usage_id, documentation: { type: Integer })
  expose(:hidden, documentation: { type: 'Boolean' })
  expose(:locked, documentation: { type: 'Boolean' })
  expose(:color, documentation: { type: String, desc: 'Color code with #. For instance: #FF0000.' })
  expose(:geojson, documentation: { type: String, desc: 'Geojson string of track and stops of the route. Default empty, set parameter geojson=true|point|polyline to get this extra content.' }) { |m, options|
    if options[:geojson] && options[:geojson] != :false
      m.to_geojson(true, true,
        if options[:geojson] == :polyline
          :polyline
        elsif options[:geojson] == :point
          false
        else
          true
        end)
    end
  }
end
