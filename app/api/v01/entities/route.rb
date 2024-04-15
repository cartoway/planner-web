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
  def self.entity_name
    'V01_Route'
  end

  expose(:ref, documentation: { type: String })
  expose(:vehicle_ref, documentation: { type: String, desc: 'Vehicle ref' }) { |m|
    m.vehicle_usage&.vehicle&.ref
  }
  expose(:distance, documentation: { type: Float, desc: 'Total route\'s distance.' })
  expose(:emission, documentation: { type: Float })
  expose(:vehicle_usage_id, documentation: { type: Integer })
  expose(:force_start, documentation: { type: 'Boolean', desc: 'DEPRECATED. To be configured on vehicle_usage_set.' })
  expose(:start, documentation: { type: DateTime }) { |m|
    (m.planning.date || Time.zone.today).beginning_of_day + m.start if m.start
  }
  expose(:end, documentation: { type: DateTime }) { |m|
    (m.planning.date || Time.zone.today).beginning_of_day + m.end if m.end
  }
  expose(:outdated, as: :out_of_date, documentation: { type: 'Boolean', desc: 'DEPRECATED. Use outdated instead.' })
  expose(:outdated, documentation: { type: 'Boolean' })

  expose(:departure_status, documentation: { type: String, desc: 'Departure status of start store.' }) { |route| route.departure_status && I18n.t('plannings.edit.stop_status.' + route.departure_status.downcase, default: route.departure_status) }
  expose(:departure_eta, documentation: { type: DateTime, desc: 'Estimated time of departure from remote device for start store.' })

  expose(:arrival_status, documentation: { type: String, desc: 'Arrival status of stop store.' }) { |route| route.arrival_status && I18n.t('plannings.edit.stop_status.' + route.arrival_status.downcase, default: route.arrival_status) }
  expose(:arrival_eta, documentation: { type: DateTime, desc: 'Estimated time of arrival from remote device for stop store.' })

  expose(:stops, using: V01::Entities::Stop, documentation: { type: V01::Entities::Stop, is_array: true })
  expose(:stop_out_of_drive_time, documentation: { type: 'Boolean' })
  expose(:stop_out_of_work_time, documentation: { type: 'Boolean' })
  expose(:stop_out_of_max_distance, documentation: { type: 'Boolean' })
  expose(:stop_distance, documentation: { type: Float, desc: 'Distance between the vehicle\'s store_stop and last stop.' })
  expose(:stop_drive_time, documentation: { type: Integer, desc: 'Time in seconds between the vehicle\'s store_stop and last stop.' })
  expose(:updated_at, documentation: { type: DateTime, desc: 'Last Updated At.'})
  expose(:last_sent_to, documentation: { type: String, desc: 'Type GPS Device of Last Sent.'})
  expose(:last_sent_at, documentation: { type: DateTime, desc: 'Last Time Sent To External GPS Device.'})
  expose(:optimized_at, documentation: { type: DateTime, desc: 'Last optimized at.'})
  expose(:out_of_max_ride_distance, documentation: { type: 'Boolean' })
  expose(:out_of_max_ride_duration, documentation: { type: 'Boolean' })
  expose(:quantities, using: V01::Entities::DeliverableUnitQuantity, documentation: { type: V01::Entities::DeliverableUnitQuantity, is_array: true, param_type: 'form' }) { |m|
    m.quantities ? m.quantities.to_a.collect{ |a| {deliverable_unit_id: a[0], quantity: a[1]} } : []
  }
  expose(:geojson, documentation: { type: String, desc: 'Geojson string of track and stops of the route. Default empty, set parameter geojson=true|point|polyline to get this extra content.' }) { |m, options|
    if options[:geojson] != :false
      m.to_geojson(true, true,
        if options[:geojson] == :polyline
          :polyline
        elsif options[:geojson] == :point
          false
        else
          true
        end)
    end
  }
end

class V01::Entities::RouteStatus < Grape::Entity
  def self.entity_name
    'V01_RouteStatus'
  end

  expose(:id, documentation: { type: Integer })
  expose(:vehicle_usage_id, documentation: { type: Integer })
  expose(:last_sent_to, documentation: { type: String, desc: 'Type GPS Device of Last Sent.'})
  expose(:last_sent_at, documentation: { type: DateTime, desc: 'Last Time Sent To External GPS Device.'})
  expose(:quantities, using: V01::Entities::DeliverableUnitQuantity, documentation: { type: V01::Entities::DeliverableUnitQuantity, is_array: true, param_type: 'form' }) { |m|
    m.quantities ? m.quantities.to_a.collect{ |a| {deliverable_unit_id: a[0], quantity: a[1]} } : []
  }
  expose(:stops, using: V01::Entities::StopStatus, documentation: { type: V01::Entities::StopStatus, is_array: true })
end

class V01::Entities::RouteProperties < Grape::Entity
  def self.entity_name
    'V01_RouteProperties'
  end

  expose(:id, documentation: { type: Integer })
  expose(:vehicle_usage_id, documentation: { type: Integer })
  expose(:start, documentation: { type: DateTime }) { |m|
    (m.planning.date || Time.zone.today).beginning_of_day + m.start if m.start
  }
  expose(:end, documentation: { type: DateTime }) { |m|
    (m.planning.date || Time.zone.today).beginning_of_day + m.end if m.end
  }
  expose(:hidden, documentation: { type: 'Boolean' })
  expose(:locked, documentation: { type: 'Boolean' })
  expose(:color, documentation: { type: String, desc: 'Color code with #. For instance: #FF0000.' })
  expose(:date, documentation: { type: Date, desc: 'DEPRECATED. Get value from the planning.' }) { |m|
    m.planning.date || Time.zone.today
  }
  expose(:force_start, documentation: { type: 'Boolean', desc: 'DEPRECATED. To be configured on vehicle_usage_set.' })
  expose(:geojson, documentation: { type: String, desc: 'Geojson string of track and stops of the route. Default empty, set parameter geojson=true|point|polyline to get this extra content.' }) { |m, options|
    if options[:geojson] != :false
      m.to_geojson(true, true,
        if options[:geojson] == :polyline
          :polyline
        elsif options[:geojson] == :point
          false
        else
          true
        end)
    end
  }
end
