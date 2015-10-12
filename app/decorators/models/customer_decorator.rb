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
Customer.class_eval do
  def stores_by_distance(position, &matrix_progress)
    starts = [[position.lat, position.lng]]
    dests = self.stores.select{ |store| !store.lat.nil? && !store.lng.nil? }.collect{ |store| [store.lat, store.lng] }
    distances = router.matrix(starts, dests, speed_multiplicator || 1, &matrix_progress)[0]
    stores.zip(distances)
  end

  def destinations_inside_time_distance(position, distance, time, &matrix_progress)
    starts = [[position.lat, position.lng]]
    dest_with_pos = self.destinations.select{ |d| !d.lat.nil? && !d.lng.nil? }
    dests = dest_with_pos.collect{ |d| [d.lat, d.lng] }
    distances = router.matrix(starts, dests, speed_multiplicator || 1, 'distance', &matrix_progress)[0]
    times = router.matrix(starts, dests, speed_multiplicator || 1, 'time', &matrix_progress)[0]
    dest_with_pos.zip(distances, times).select{ |dest, dist, t|
      check_distance, check_time = true, true
      if distance
        check_distance = (dist[0] <= distance)
      end
      if time
        check_time = (t[0] <= time)
      end
      check_time && check_distance
    }.collect{ |dest, d, t| dest }
  end
end
