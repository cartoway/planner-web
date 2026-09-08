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
class V01::Entities::VehicleUsage < Grape::Entity
  def self.entity_name
    'V01_VehicleUsage'
  end

  expose(:id, documentation: { type: Integer, desc: 'Internal identifier.', example: 8 })
  expose(:vehicle_usage_set_id, documentation: { type: Integer, desc: 'Parent usage set (context: morning, evening, …).', example: 1 })
  expose(:time_window_start, documentation: { type: DateTime, desc: 'Shift start (HH:MM on input). Falls back to the set default when unset.' }) { |m| m.time_window_start_absolute_time_with_seconds }
  expose(:time_window_end, documentation: { type: DateTime, desc: 'Shift end (HH:MM on input). Falls back to the set default when unset.' }) { |m| m.time_window_end_absolute_time_with_seconds }
  expose(:max_reload, documentation: { type: Integer, desc: 'Maximum number of reloads per route. Falls back to the set default.' })
  expose(:store_start_id, documentation: { type: Integer, desc: 'Start depot store id. Falls back to the set default.' })
  expose(:store_stop_id, documentation: { type: Integer, desc: 'End depot store id. Falls back to the set default.' })
  expose(:store_reload_ids, documentation: { type: Integer, is_array: true, desc: 'Reload store ids allowed on this usage. Falls back to the set default.' }) { |m| m.store_reloads.map(&:id) }
  expose(:service_time_start, documentation: { type: DateTime, desc: 'Service time at the start store (HH:MM on input).' }) { |m| m.service_time_start_absolute_time_with_seconds }
  expose(:service_time_end, documentation: { type: DateTime, desc: 'Service time at the stop store (HH:MM on input).' }) { |m| m.service_time_end_absolute_time_with_seconds }
  expose(:work_time, documentation: { type: DateTime, desc: 'Maximum working duration (HH:MM on input).' }) { |m| m.work_time_absolute_time_with_seconds }
  expose(:rest_start, documentation: { type: DateTime, desc: 'Earliest rest start (HH:MM on input).' }) { |m| m.rest_start_absolute_time_with_seconds }
  expose(:rest_stop, documentation: { type: DateTime, desc: 'Latest rest end (HH:MM on input).' }) { |m| m.rest_stop_absolute_time_with_seconds }
  expose(:rest_duration, documentation: { type: DateTime, desc: 'Rest duration (HH:MM on input).' }) { |m| m.rest_duration_absolute_time_with_seconds }
  expose(:rest_lapse, documentation: { type: DateTime, desc: 'Work lapse between cumulative rests (HH:MM on input).' }) { |m| m.rest_lapse_absolute_time_with_seconds }
  expose(:store_rest_id, documentation: { type: Integer, desc: 'Store used as rest location when set.' })
  expose(:active, documentation: { type: 'Boolean', desc: 'When false, no route is built for this usage in new plannings.', example: true })
  expose(:visit_duration_coef, documentation: { type: Float, desc: 'Coefficient applied to visit durations (falls back to vehicle usage set, then 1)' })
  expose(:destination_duration_coef, documentation: { type: Float, desc: 'Coefficient applied to destination durations (falls back to vehicle usage set, then 1)' })
  expose(:tag_ids, documentation: { type: Integer, is_array: true, desc: 'Extra skills for this usage, in addition to the vehicle tags.' })

  # Deprecated fields
  expose(:open, documentation: { hidden: true, type: DateTime, desc: 'Deprecated, use `visit_duration` instead' }) { |m| m.time_window_start_absolute_time_with_seconds }
  expose(:close, documentation: { hidden: true, type: DateTime, desc: 'Deprecated, use `time_window_end` instead.' }) { |m| m.time_window_end_absolute_time_with_seconds }
end

class V01::Entities::VehicleUsageWithVehicle < V01::Entities::VehicleUsage
  def self.entity_name
    'V01_VehicleUsageWithVehicle'
  end

  expose(:vehicle, using: V01::Entities::VehicleWithoutVehicleUsage, documentation: { type: V01::Entities::VehicleWithoutVehicleUsage, is_array: true })
end
