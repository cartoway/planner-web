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
class V01::Entities::Layer < Grape::Entity
  def self.entity_name
    'V01_Layer'
  end

  expose(:id, documentation: { type: Integer })
  expose(:name, documentation: { type: String })
  expose(:url, documentation: { type: String })
  expose(:attribution, documentation: { type: String })
  expose(:vector_style_url, documentation: { type: String, desc: 'Optional MapLibre style JSON URL for vector layers (MapLibre GL).' })
  expose(:source, documentation: { type: String })
  expose(:overlay, documentation: { type: 'Boolean', desc: 'False if it is a base layer, true if it is just an overlay.' })
end
