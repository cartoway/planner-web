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
class V01::Entities::DeviceRouteLastSentAt < Grape::Entity
  def self.entity_name
    'V01_Devices_DeviceRouteLastSentAt'
  end

  expose(:id, documentation: { type: Integer, desc: 'Planning Route ID, or OperationRoute ID for Deliver.' })
  expose(:last_sent_to, documentation: { type: String, desc: 'Type GPS Device of Last Sent'})
  expose(:last_sent_at, documentation: { type: DateTime, desc: 'Last Time Sent To External GPS Device'})
  expose(:last_sent_at_formatted, documentation: { type: String }) { |m|
    m.last_sent_at && I18n.l(m.last_sent_at.in_time_zone(Time.zone))
  }
end
