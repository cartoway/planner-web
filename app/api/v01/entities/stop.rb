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
class V01::Entities::Stop < V01::Entities::StopStatus
  def self.entity_name
    'V01_Stop'
  end

  expose(:destination_ref, documentation: { type: String, desc: 'Ref of the destination (StopVisit) or store (StopStore).' }) { |stop|
    if stop.is_a?(StopVisit) && stop.visit && stop.visit.destination
      stop.visit.destination.ref
    elsif stop.is_a?(StopStore) && stop.store_reload && stop.store_reload.store
      stop.store_reload.store.ref
    end
  }
  expose(:visit_ref, documentation: { type: String, desc: 'Ref of the visit (StopVisit) or store reload (StopStore).' }) { |stop|
    if stop.is_a?(StopVisit) && stop.visit
      stop.visit.ref
    elsif stop.is_a?(StopStore) && stop.store_reload
      stop.store_reload.ref
    end
  }
  expose(:active, documentation: { type: 'Boolean', desc: 'When false the stop is skipped (not visited) but kept on the route.', example: true })
  expose(:locked, documentation: { type: 'Boolean', desc: 'When true, optimization keeps this visit on its current vehicle route (StopVisit only).', example: false })
  expose(:distance, documentation: { type: Float, desc: 'Distance in meters between this stop and the previous one.' })
  expose(:drive_time, documentation: { type: Integer, desc: 'Drive time in seconds between this stop and the previous one.' })
  expose(:visit_id, documentation: { type: Integer, desc: 'Visit id when stop_type is visit.' })
  expose(:route_id, documentation: { type: Integer, desc: 'Route this stop belongs to.' }) { |stop|
    stop.route_id
  }
  expose(:planning_id, documentation: { type: Integer, desc: 'Planning this stop belongs to.' }) { |stop|
    stop.route.planning_id
  }
  # Deprecated
  expose(:destination_id, documentation: { hidden: true, deprecated: true, type: Integer, desc: 'DEPRECATED. Destination id when stop_type is visit.' }) { |m| m.is_a?(StopVisit) ? m.visit.destination.id : nil }
  expose(:wait_time, documentation: { type: DateTime, desc: 'Waiting time before service (HH:MM:SS) when arriving early for the time window.' }) { |m| m.wait_time && ('%i:%02i:%02i' % [m.wait_time / 60 / 60, m.wait_time / 60 % 60, m.wait_time % 60]) }
  expose(:time, documentation: { type: DateTime, desc: 'Planned arrival datetime.' }) { |m|
    (m.route.planning.date || Time.zone.today).beginning_of_day + m.time if m.time
  }
  expose(:no_path, documentation: { type: 'Boolean', desc: 'True when the router found no path from the previous stop.' })
  expose(:out_of_skill, documentation: { type: 'Boolean', desc: 'True when the visit tags are not present on the vehicle.' })
  expose(:out_of_window, documentation: { type: 'Boolean', desc: 'True when planned arrival is outside visit time windows.' })
  expose(:out_of_capacity, documentation: { type: 'Boolean', desc: 'True when load at this stop exceeds vehicle capacity.' })
  expose(:out_of_drive_time, documentation: { type: 'Boolean', desc: 'True when arrival exceeds the vehicle drive time window.' })
  expose(:out_of_force_position, documentation: { type: 'Boolean', desc: 'True when visit force_position is not respected at this index.' })
  expose(:out_of_work_time, documentation: { type: 'Boolean', desc: 'True when arrival exceeds vehicle work_time.' })
  expose(:out_of_max_distance, documentation: { type: 'Boolean', desc: 'True when cumulative distance exceeds vehicle max_distance.' })
  expose(:out_of_max_ride_distance, documentation: { type: 'Boolean', desc: 'True when the leg from the previous stop exceeds max_ride_distance.' })
  expose(:out_of_max_ride_duration, documentation: { type: 'Boolean', desc: 'True when the leg from the previous stop exceeds max_ride_duration.' })
  expose(:out_of_max_reload, documentation: { type: 'Boolean', desc: 'True when reload count so far exceeds vehicle max_reload.' })
  expose(:out_of_relation, documentation: { type: 'Boolean', desc: 'True when a visit relation involving this stop is not respected.' })
  expose(:unmanageable_capacity, documentation: { type: 'Boolean', desc: 'Capacity units used by the stop are not configured on the vehicle.' })
  expose(:custom_attributes_typed_hash, documentation: { type: Hash, desc: 'Additional typed properties defined on CustomAttribute for stops/visits.' }, as: :custom_attributes)
  expose(:photos, documentation: { type: Hash, is_array: true, desc: 'Stop photos with temporary signed URLs (expire after 15 minutes).' }) { |stop, options|
    stop.serialized_photos(host: Stop.photo_host_from_env(options[:env]))
  }
end
