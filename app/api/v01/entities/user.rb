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
class V01::Entities::User < Grape::Entity
  def self.entity_name
    'V01_User'
  end

  expose(:id, documentation: { type: Integer })
  expose(:ref, documentation: { type: String, desc: 'Only available in admin.' })
  expose(:email, documentation: { type: String })
  expose(:customer_id, documentation: { type: Integer })
  expose(:layer_id, documentation: { type: Integer })
  expose(:api_key, documentation: { type: String })
  expose(:url_click2call, documentation: { type: String })
  expose(:prefered_unit, documentation: { type: String })
  expose(:locale, documentation: { type: String, desc: 'Currently used in mailing' })
  expose(:time_zone, documentation: { type: String })
end
