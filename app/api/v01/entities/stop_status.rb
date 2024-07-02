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

  expose(:id, documentation: { type: Integer })
  expose(:index, documentation: { type: Integer, desc: 'Stop\'s Index' })
  expose(:status, documentation: { type: String, desc: 'Status of stop.' }) { |stop| stop.status && I18n.t('plannings.edit.stop_status.' + stop.status.downcase, default: stop.status) }
  expose(:status_code, documentation: { type: String, desc: 'Status code of stop.' }) { |stop| stop.status && stop.status.downcase }
  expose(:status_updated_at, documentation: { type: DateTime, desc: 'Time when the status has been updated'})
  expose(:eta, documentation: { type: DateTime, desc: 'Estimated time of arrival from remote device.' })
  expose(:eta_formated, documentation: { type: DateTime, desc: 'Estimated time of arrival from remote device.' }) { |stop| stop.eta && I18n.l(stop.eta, format: :hour_minute) }
end
