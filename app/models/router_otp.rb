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
require 'routers/otp'

class RouterOtp < Router
  validates :url_time, presence: true

  def trace(_speed_multiplicator, lat1, lng1, lat2, lng2, _dimension = :time, _options = {})
    # No speed_multiplicator
    Planner::Application.config.router_otp.compute(url_time, ref, lat1, lng1, lat2, lng2, monday_morning)
  end

  def matrix(row, column, speed_multiplicator, dimension = :time, _options = {}, &block)
    # No speed_multiplicator
    matrix_iterate(row, column, speed_multiplicator, dimension, &block)
  end

  def isochrone?
    true
  end

  def compute_isochrone(lat, lng, size, _speed_multiplicator, _options = {})
    # No speed_multiplicator
    Planner::Application.config.router_otp.isochrone(url_time, ref, lat, lng, size, monday_morning)
  end

  private

  def monday_morning
    monday_morning = Time.zone.today
    monday_morning -= monday_morning.cwday - 1 # Go to last monday
    monday_morning.to_time + 9.hours # Go to monday 09:00
  end
end
