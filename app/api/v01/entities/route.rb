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
class V01::Entities::Route < V01::Entities::RouteProperties
  include QuantitiesEntityHelper

  def self.entity_name
    'V01_Route'
  end

  expose(:ref, documentation: { type: String, desc: 'External reference of the route.', example: 'VEH-1' })
  expose(:vehicle_ref, documentation: { type: String, desc: 'Ref of the vehicle assigned to this route. Null on the unassigned route.' }) { |m|
    m.vehicle_usage&.vehicle&.ref
  }
  expose(:distance, documentation: { type: Float, desc: 'Total route distance in meters.' })
  expose(:emission, documentation: { type: Float, desc: 'Estimated CO2 emission for the route.' })
  expose(:vehicle_usage_id, documentation: { type: Integer, desc: 'Vehicle usage driving this route. Null on the unassigned (out-of-route) route.' })
  expose(:force_start, documentation: { type: 'Boolean', desc: 'DEPRECATED. To be configured on vehicle_usage_set.' })
  expose(:start, documentation: { type: DateTime, desc: 'Computed departure datetime from the start store.' }) { |m|
    (m.planning.date || Time.zone.today).beginning_of_day + m.start if m.start
  }
  expose(:end, documentation: { type: DateTime, desc: 'Computed arrival datetime at the stop store.' }) { |m|
    (m.planning.date || Time.zone.today).beginning_of_day + m.end if m.end
  }
  expose(:outdated, as: :out_of_date, documentation: { type: 'Boolean', desc: 'DEPRECATED. Use outdated instead.' })
  expose(:outdated, documentation: { type: 'Boolean', desc: 'True when times/distances are stale and must be recomputed (refresh or next compute_saved).' })

  expose(:departure_status, documentation: { type: String, desc: 'Departure status of start store.' }) { |route| route.start_route_data&.status && I18n.t('plannings.edit.stop_status.' + route.start_route_data.status.downcase, default: route.start_route_data.status) }
  expose(:departure_eta, documentation: { type: DateTime, desc: 'Estimated time of departure from remote device for start store.' })
  expose(:departure, documentation: { type: DateTime, desc: 'Forced departure time of start store.' })
  expose(:arrival_status, documentation: { type: String, desc: 'Arrival status of stop store.' }) { |route| route.stop_route_data&.status && I18n.t('plannings.edit.stop_status.' + route.stop_route_data.status.downcase, default: route.stop_route_data.status) }
  expose(:arrival_eta, documentation: { type: DateTime, desc: 'Estimated time of arrival from remote device for stop store.' })

  expose(:stops, using: V01::Entities::Stop, documentation: { type: V01::Entities::Stop, is_array: true, desc: 'Ordered stops (visits, reloads, rests) on this route.' })
  expose(:stop_out_of_drive_time, documentation: { type: 'Boolean', desc: 'True when the last stop exceeds the vehicle drive-time window.' })
  expose(:stop_out_of_work_time, documentation: { type: 'Boolean', desc: 'True when the last stop exceeds the vehicle work time.' })
  expose(:stop_out_of_max_distance, documentation: { type: 'Boolean', desc: 'True when the last stop exceeds the vehicle max distance.' })
  expose(:stop_distance, documentation: { type: Float, desc: 'Distance in meters between the vehicle store_stop and last stop.' })
  expose(:stop_drive_time, documentation: { type: Integer, desc: 'Time in seconds between the vehicle store_stop and last stop.' })
  expose(:updated_at, documentation: { type: DateTime, desc: 'Last Updated At.'})
  expose(:last_sent_to, documentation: { type: String, desc: 'Type GPS Device of Last Sent.'})
  expose(:last_sent_at, documentation: { type: DateTime, desc: 'Last Time Sent To External GPS Device.'})
  expose(:optimized_at, documentation: { type: DateTime, desc: 'Last optimized at.'})
  expose(:out_of_max_ride_distance, documentation: { type: 'Boolean', desc: 'True when at least one leg exceeds max_ride_distance.' })
  expose(:out_of_max_ride_duration, documentation: { type: 'Boolean', desc: 'True when at least one leg exceeds max_ride_duration.' })
  expose(:size_active, documentation: { type: Integer, desc: 'Count of active stops on the main route_data.' })
  expose(:size_destinations, documentation: { type: Integer, desc: 'Count of stops linked to a destination (visits).' })
  expose(:size_active_destinations, documentation: { type: Integer, desc: 'Count of active stops linked to a destination.' })
  expose(:size_store_reloads, documentation: { type: Integer, desc: 'Count of reload stops.' })
  expose(:stops_size, documentation: { type: Integer, desc: 'Total number of stops including inactive.' })
  expose(:no_geolocalization, documentation: { type: 'Boolean', desc: 'True when at least one stop has no coordinates.' })
  expose(:no_path, documentation: { type: 'Boolean', desc: 'True when the router found no path for at least one leg.' })
  expose(:unmanageable_capacity, documentation: { type: 'Boolean', desc: 'True when a stop uses a deliverable unit not configured on the vehicle.' })
  expose(:out_of_capacity, documentation: { type: 'Boolean', desc: 'True when load exceeds vehicle capacity on at least one stop.' })
  expose(:out_of_drive_time, documentation: { type: 'Boolean', desc: 'True when the route exceeds the vehicle time window (drive).' })
  expose(:out_of_force_position, documentation: { type: 'Boolean', desc: 'True when a visit force_position constraint is not respected.' })
  expose(:out_of_work_time, documentation: { type: 'Boolean', desc: 'True when the route exceeds vehicle work_time.' })
  expose(:out_of_window, documentation: { type: 'Boolean', desc: 'True when at least one stop is outside its visit time windows.' })
  expose(:out_of_max_distance, documentation: { type: 'Boolean', desc: 'True when total distance exceeds vehicle max_distance.' })
  expose(:out_of_max_reload, documentation: { type: 'Boolean', desc: 'True when reload count exceeds vehicle max_reload.' })
  expose(:out_of_relation, documentation: { type: 'Boolean', desc: 'True when a visit relation (pickup/delivery, sequence, …) is not respected.' })
  expose(:out_of_skill, documentation: { type: 'Boolean', desc: 'True when a visit tag (skill) is not present on the vehicle.' })
  expose(:max_loads, documentation: { type: Hash, desc: 'Main route_data max loads (jsonb).' })
  expose(:quantities, using: V01::Entities::DeliverableUnitQuantity, documentation: { type: V01::Entities::DeliverableUnitQuantity, is_array: true, param_type: 'form' }) { |m|
    convert_pickups_deliveries_to_quantities(m.pickups, m.deliveries)
  }
  expose(:geojson, documentation: { type: String, desc: 'Geojson string of track and stops of the route. Default empty, set parameter geojson=true|point|polyline to get this extra content.' }) { |m, options|
    if options[:geojson] && options[:geojson] != :false
      m.to_geojson(true, true,
        if options[:geojson] == :polyline
          :polyline
        elsif options[:geojson] == :point
          false
        else
          true
        end,
        false,
        options[:sub_tour_indices])
    end
  }
end

class V01::Entities::RouteStatus < Grape::Entity
  include QuantitiesEntityHelper

  def self.entity_name
    'V01_RouteStatus'
  end

  expose(:id, documentation: { type: Integer, desc: 'Internal identifier.', example: 20 })
  expose(:vehicle_usage_id, documentation: { type: Integer, desc: 'Vehicle usage driving this route. Null on the unassigned route.' })
  expose(:last_sent_to, documentation: { type: String, desc: 'Type GPS Device of Last Sent.'})
  expose(:last_sent_at, documentation: { type: DateTime, desc: 'Last Time Sent To External GPS Device.'})
  expose(:out_of_max_ride_distance, documentation: { type: 'Boolean', desc: 'True when at least one leg exceeds max_ride_distance.' })
  expose(:out_of_max_ride_duration, documentation: { type: 'Boolean', desc: 'True when at least one leg exceeds max_ride_duration.' })
  expose(:size_active, documentation: { type: Integer, desc: 'Count of active stops on the main route_data.' })
  expose(:size_destinations, documentation: { type: Integer, desc: 'Count of stops linked to a destination (visits).' })
  expose(:size_active_destinations, documentation: { type: Integer, desc: 'Count of active stops linked to a destination.' })
  expose(:size_store_reloads, documentation: { type: Integer, desc: 'Count of reload stops.' })
  expose(:stops_size, documentation: { type: Integer, desc: 'Total number of stops including inactive.' })
  expose(:no_geolocalization, documentation: { type: 'Boolean', desc: 'True when at least one stop has no coordinates.' })
  expose(:no_path, documentation: { type: 'Boolean', desc: 'True when the router found no path for at least one leg.' })
  expose(:unmanageable_capacity, documentation: { type: 'Boolean', desc: 'True when a stop uses a deliverable unit not configured on the vehicle.' })
  expose(:out_of_capacity, documentation: { type: 'Boolean', desc: 'True when load exceeds vehicle capacity on at least one stop.' })
  expose(:out_of_drive_time, documentation: { type: 'Boolean', desc: 'True when the route exceeds the vehicle time window (drive).' })
  expose(:out_of_force_position, documentation: { type: 'Boolean', desc: 'True when a visit force_position constraint is not respected.' })
  expose(:out_of_work_time, documentation: { type: 'Boolean', desc: 'True when the route exceeds vehicle work_time.' })
  expose(:out_of_window, documentation: { type: 'Boolean', desc: 'True when at least one stop is outside its visit time windows.' })
  expose(:out_of_max_distance, documentation: { type: 'Boolean', desc: 'True when total distance exceeds vehicle max_distance.' })
  expose(:out_of_max_reload, documentation: { type: 'Boolean', desc: 'True when reload count exceeds vehicle max_reload.' })
  expose(:out_of_relation, documentation: { type: 'Boolean', desc: 'True when a visit relation is not respected.' })
  expose(:out_of_skill, documentation: { type: 'Boolean', desc: 'True when a visit tag (skill) is not present on the vehicle.' })
  expose(:max_loads, documentation: { type: Hash, desc: 'Main route_data max loads (jsonb).' })
  expose(:quantities, using: V01::Entities::DeliverableUnitQuantity, documentation: { type: V01::Entities::DeliverableUnitQuantity, is_array: true, param_type: 'form' }) { |m|
    convert_pickups_deliveries_to_quantities(m.pickups, m.deliveries)
  }
  expose(:stops, using: V01::Entities::StopStatus, documentation: { type: V01::Entities::StopStatus, is_array: true })
end

class V01::Entities::RouteProperties < Grape::Entity
  def self.entity_name
    'V01_RouteProperties'
  end

  expose(:id, documentation: { type: Integer, desc: 'Internal identifier.', example: 20 })
  expose(:vehicle_usage_id, documentation: { type: Integer, desc: 'Vehicle usage driving this route. Null on the unassigned route.' })
  expose(:departure, documentation: { type: DateTime, desc: 'Forced departure time of start store.' })
  expose(:start, documentation: { type: DateTime, desc: 'Computed departure datetime from the start store.' }) { |m|
    (m.planning.date || Time.zone.today).beginning_of_day + m.start if m.start
  }
  expose(:end, documentation: { type: DateTime, desc: 'Computed arrival datetime at the stop store.' }) { |m|
    (m.planning.date || Time.zone.today).beginning_of_day + m.end if m.end
  }
  expose(:ref, documentation: { type: String, desc: 'External reference of the route.', example: 'VEH-1' })
  expose(:hidden, documentation: { type: 'Boolean', desc: 'When true the route is hidden on the map and excluded from geojson unless respect_hidden is false.', example: false })
  expose(:locked, documentation: { type: 'Boolean', desc: 'When true, optimization does not change this route (visits stay on it).', example: false })
  expose(:color, documentation: { type: String, desc: 'Color code with #. For instance: #FF0000.', example: '#FF0000' })
  expose(:date, documentation: { type: Date, desc: 'DEPRECATED. Get value from the planning.' }) { |m|
    m.planning.date || Time.zone.today
  }
  expose(:force_start, documentation: { type: 'Boolean', desc: 'DEPRECATED. To be configured on vehicle_usage_set.' })
  expose(:geojson, documentation: { type: String, desc: 'Geojson string of track and stops of the route. Default empty, set parameter geojson=true|point|polyline to get this extra content.' }) { |m, options|
    if options[:geojson] && options[:geojson] != :false
      m.to_geojson(true, true,
        if options[:geojson] == :polyline
          :polyline
        elsif options[:geojson] == :point
          false
        else
          true
        end,
        false,
        options[:sub_tour_indices])
    end
  }
end
