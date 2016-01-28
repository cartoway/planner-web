# Copyright © Mapotempo, 2015-2016
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
Customer.class_eval do
  def stores_by_distance(position, n, vehicle_usage = nil, &matrix_progress)
    starts = [[position.lat, position.lng]]
    dests = self.stores.select{ |store| !store.lat.nil? && !store.lng.nil? }.collect{ |store| [store.lat, store.lng] }
    r = (vehicle_usage && vehicle_usage.vehicle.default_router) || router
    sm = (vehicle_usage && vehicle_usage.vehicle.default_speed_multiplicator) || speed_multiplicator || 1

    distances = r.matrix(starts, dests, sm, &matrix_progress)[0]
    stores.select{ |store, distance| !distance.nil? }.zip(distances).sort_by{ |store, distance|
      distance
    }[0..[n, stores.size].min - 1].collect{ |store, distance| store }
  end

  def destinations_inside_time_distance(position, distance, time, vehicle_usage = nil, &matrix_progress)
    starts = [[position.lat, position.lng]]
    dest_with_pos = self.destinations.select{ |d| !d.lat.nil? && !d.lng.nil? }
    dests = dest_with_pos.collect{ |d| [d.lat, d.lng] }
    r = (vehicle_usage && vehicle_usage.vehicle.default_router) || router
    sm = (vehicle_usage && vehicle_usage.vehicle.default_speed_multiplicator) || speed_multiplicator || 1

    distances = !distance.nil? && r.distance? ? r.matrix(starts, dests, sm, :distance, &matrix_progress)[0] : []
    times = !time.nil? && r.time? ? r.matrix(starts, dests, sm, :time, &matrix_progress)[0] : []
    dest_with_pos.zip(distances, times).select{ |dest, dist, t|
      (!dist || dist[0] <= distance) && (!t || t[0] <= time)
    }.collect{ |dest, d, t| dest }
  end
end
