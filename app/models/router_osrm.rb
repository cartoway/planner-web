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
require 'routers/osrm'

class RouterOsrm < Router
  validates :url_time, presence: true

  def trace(speed_multiplicator, lat1, lng1, lat2, lng2, _dimension = :time, _options = {})
    distance, time, trace = Planner::Application.config.router_osrm.compute(url_time, lat1, lng1, lat2, lng2)
    if time
      time *= 1.0 / speed_multiplicator
    end
    [distance, time, trace]
  end

  def matrix(row, column, speed_multiplicator, dimension = :time, _options = {}, &block)
    block.call(nil, nil) if block
    time_multiplicator = 1.0 / speed_multiplicator
    url = send('url_' + dimension.to_s)
    if !url
      nil
    else
      rectangular2square_matrix(row, column) { |vector|
        Planner::Application.config.router_osrm.matrix(url, vector)
      }.map{ |row|
        row.map{ |v| [v, v * time_multiplicator] }
      }
    end
  end

  def time?
    super && !url_time.nil?
  end

  def isochrone?
    super_time? && !url_isochrone.nil?
  end

  def distance?
    super && !url_distance.nil?
  end


  def compute_isochrone(lat, lng, size, speed_multiplicator, _options = {})
    Planner::Application.config.router_osrm.isochrone(url_isochrone, lat, lng, size * speed_multiplicator)
  end

  def isodistance?
    super_distance? && !url_isodistance.nil?
  end

  def compute_isodistance(lat, lng, size, _speed_multiplicator, _options = {})
    # No speed_multiplicator
    Planner::Application.config.router_osrm.isochrone(url_isodistance, lat, lng, size)
  end
end
