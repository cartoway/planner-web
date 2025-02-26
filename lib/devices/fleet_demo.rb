# Copyright © Mapotempo, 2017
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
class FleetDemo < DeviceBase
  def initialize
    ActiveSupport::Cache::FileStore.new(File.join(Dir.tmpdir, 'fleet_demo'), namespace: 'fleet_demo', expires_in: 60*60*24)
  end

  def definition
    {
      device: 'fleet_demo',
      label: 'Cartoway Field demo',
      label_small: 'Demo',
      route_operations: [:send, :clear],
      has_sync: false,
      help: true,
      forms: {
        vehicle: {
        },
      }
    }
  end

  def send_route(customer, route, _options = {})
    true
  end

  def clear_route(customer, route)
    true
  end

  def fetch_stops(customer, date, planning)
    date = (planning.date || Time.zone.now).at_midnight
    planning.routes.select(&:vehicle_usage_id).flat_map{ |r|
      if r.last_sent_at && r.last_sent_at.utc.at_midnight == Time.now.utc.at_midnight
        started = false
        r.stops.select(&:active).each_with_index.map { |s, i|
          {
            order_id: (s.is_a?(StopVisit) ? "v#{s.visit_id}" : "r#{s.id}"),
            status: i < r.stops.size / 4 ? :finished : !started ? started = :started : :planned,
            # status: s.time && (date < Time.now - 60 ? :finished : date < Time.now ? :started : :planned),
            eta: s.time && (date + s.time + i * 60)
          }
        }
      else
        r.stops.select(&:status).map { |s|
          {
            order_id: (s.is_a?(StopVisit) ? "v#{s.visit_id}" : "r#{s.id}"),
            status: s.status,
            eta: s.eta
          }
        }
      end
    }.compact
  end

  def vehicle_pos(customer)
    planning = customer.plannings.sort_by(&:updated_at).last
    customer.vehicles.map{ |v|
      route = planning.routes.find{ |r| r.vehicle_usage && r.vehicle_usage.vehicle_id == v.id }
      stops = route ? route.stops.select{ |s| s.position? } : []
      {
        vehicle_id: v.id,
        device_name: v.name,
        lat: stops.size > 0 ? stops.map{ |s| s.position.lat }.sum(0) / stops.size + Random.new.rand(10) * 0.01 : customer.stores.first.lat,
        lng: stops.size > 0 ? stops.map{ |s| s.position.lng }.sum(0) / stops.size + Random.new.rand(10) * 0.01 : customer.stores.first.lng,
        time: Time.now,
        speed: stops.size > 0 ? Random.new.rand(90) : 0,
        direction: stops.size > 0 ? Random.new.rand(360) : 0
      }
    }
  end
end
