# Copyright © Mapotempo, 2014-2016
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
class V01::Entities::StopStatus < Grape::Entity
  def self.entity_name
    'V01_StopStatus'
  end

  STOP_TYPES = { StopVisit: 'visit', StopStore: 'reload', StopRest: 'rest' }.freeze

  expose(:id, documentation: { type: Integer, desc: 'Internal identifier.', example: 55 })
  expose(:index, documentation: { type: Integer, desc: '1-based position of the stop in the route. Use -1 when moving to append at the end.', example: 3 })
  expose(:stop_type, documentation: { type: String, desc: 'Type of stop: visit, reload or rest.', example: 'visit' }) { |stop| STOP_TYPES[stop.class.name.to_sym] }
end
