# Copyright © Mapotempo, 2015
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
class V01::Entities::VehicleUsageSet < Grape::Entity
  def self.entity_name
    'V01_VehicleUsageSet'
  end

  expose(:id, documentation: { type: Integer })
  expose(:name, documentation: { type: String })
  expose(:time_window_start, documentation: { type: DateTime }) { |m| m.time_window_start_absolute_time_with_seconds }
  expose(:time_window_end, documentation: { type: DateTime }) { |m| m.time_window_end_absolute_time_with_seconds }
  expose(:store_start_id, documentation: { type: Integer })
  expose(:store_stop_id, documentation: { type: Integer })
  expose(:service_time_start, documentation: { type: DateTime }) { |m| m.service_time_start_absolute_time_with_seconds }
  expose(:service_time_end, documentation: { type: DateTime }) { |m| m.service_time_end_absolute_time_with_seconds }
  expose(:work_time, documentation: { type: DateTime }) { |m| m.work_time_absolute_time_with_seconds }
  expose(:rest_start, documentation: { type: DateTime }) { |m| m.rest_start_absolute_time_with_seconds }
  expose(:rest_stop, documentation: { type: DateTime }) { |m| m.rest_stop_absolute_time_with_seconds }
  expose(:rest_duration, documentation: { type: DateTime }) { |m| m.rest_duration_absolute_time_with_seconds }
  expose(:store_rest_id, documentation: { type: Integer })
  expose(:max_distance, documentation: { type: Integer, desc: 'Maximum achievable distance in meters' })
  expose(:max_ride_distance, documentation: { type: Integer, desc: 'Maximum riding distance between two stops within a route in meters' })
  expose(:max_ride_duration, documentation: { type: DateTime, desc: 'Maximum riding time between two stops within a route' }) { |m| m.max_ride_duration_absolute_time_with_seconds }

  # Deprecated fields
  expose(:open, documentation: { hidden: true, type: DateTime, desc: 'Deprecated, use `visit_duration` instead' }) { |m| m.time_window_start_absolute_time_with_seconds }
  expose(:close, documentation: { hidden: true, type: DateTime, desc: 'Deprecated, use `time_window_end` instead.' }) { |m| m.time_window_end_absolute_time_with_seconds }
end
