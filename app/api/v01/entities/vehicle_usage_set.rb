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

  expose(:id, documentation: { type: Integer, desc: 'Internal identifier.', example: 1 })
  expose(:name, documentation: { type: String, desc: 'Display name of the context (Morning, Evening, …).', example: 'Default' })
  expose(:time_window_start, documentation: { type: DateTime, desc: 'Default shift start (HH:MM on input) inherited by vehicle usages.' }) { |m| m.time_window_start_absolute_time_with_seconds }
  expose(:time_window_end, documentation: { type: DateTime, desc: 'Default shift end (HH:MM on input) inherited by vehicle usages.' }) { |m| m.time_window_end_absolute_time_with_seconds }
  expose(:store_start_id, documentation: { type: Integer, desc: 'Default start depot store id.' })
  expose(:store_stop_id, documentation: { type: Integer, desc: 'Default end depot store id.' })
  expose(:store_reload_ids, documentation: { type: Integer, is_array: true, desc: 'Default reload store ids inherited by vehicle usages.' }) { |m| m.store_reloads.map(&:id) }
  expose(:service_time_start, documentation: { type: DateTime, desc: 'Default service time at the start store (HH:MM on input).' }) { |m| m.service_time_start_absolute_time_with_seconds }
  expose(:service_time_end, documentation: { type: DateTime, desc: 'Default service time at the stop store (HH:MM on input).' }) { |m| m.service_time_end_absolute_time_with_seconds }
  expose(:work_time, documentation: { type: DateTime, desc: 'Default maximum working duration (HH:MM on input).' }) { |m| m.work_time_absolute_time_with_seconds }
  expose(:rest_start, documentation: { type: DateTime, desc: 'Default earliest rest start (HH:MM on input).' }) { |m| m.rest_start_absolute_time_with_seconds }
  expose(:rest_stop, documentation: { type: DateTime, desc: 'Default latest rest end (HH:MM on input).' }) { |m| m.rest_stop_absolute_time_with_seconds }
  expose(:rest_duration, documentation: { type: DateTime, desc: 'Default rest duration (HH:MM on input).' }) { |m| m.rest_duration_absolute_time_with_seconds }
  expose(:rest_lapse, documentation: { type: DateTime, desc: 'Default work lapse between cumulative rests (HH:MM on input).' }) { |m| m.rest_lapse_absolute_time_with_seconds }
  expose(:store_rest_id, documentation: { type: Integer, desc: 'Default rest store id.' })
  expose(:max_reload, documentation: { type: Integer, desc: 'Maximum number of reloads per route' })
  expose(:max_distance, documentation: { type: Integer, desc: 'Maximum achievable distance in meters' })
  expose(:max_ride_distance, documentation: { type: Integer, desc: 'Maximum riding distance between two stops within a route in meters' })
  expose(:max_ride_duration, documentation: { type: DateTime, desc: 'Maximum riding time between two stops within a route' }) { |m| m.max_ride_duration_absolute_time_with_seconds }
  expose(:visit_duration_coef, documentation: { type: Float, desc: 'Default coefficient applied to visit durations for vehicle usages in this set (default: 1)' })
  expose(:destination_duration_coef, documentation: { type: Float, desc: 'Default coefficient applied to destination durations for vehicle usages in this set (default: 1)' })

  # Deprecated fields
  expose(:open, documentation: { hidden: true, type: DateTime, desc: 'Deprecated, use `visit_duration` instead' }) { |m| m.time_window_start_absolute_time_with_seconds }
  expose(:close, documentation: { hidden: true, type: DateTime, desc: 'Deprecated, use `time_window_end` instead.' }) { |m| m.time_window_end_absolute_time_with_seconds }
end
