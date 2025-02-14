# Copyright © Mapotempo, 2016
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
require 'routers/router_wrapper'

class RouterWrapper < Router
  def trace(lat1, lng1, lat2, lng2, dimension = :time, options = {})
    trace_batch([[lat1, lng1, lat2, lng2]], dimension, options)
  end

  def trace_batch(segments, dimension = :time, options = {})
    Planner::Application.config.router.compute_batch(default_url, mode, dimension, segments, sanitize_options(options))
  end

  def matrix(row, column, dimension = :time, options = {}, &block)
    block.call(nil, nil) if block

    matrix = Planner::Application.config.router.matrix(default_url, mode, [dimension], row, column, sanitize_options(options))
    matrix ||= [Array.new(row.size) { Array.new(column.size, 2147483647) }]

    matrix[0].map{ |row|
      row.map{ |v| [v, v] }
    }
  end

  def compute_isochrone(lat, lng, size, options = {})
    Planner::Application.config.router.isoline(default_url, mode, :time, lat, lng, size, sanitize_options(options))
  end

  def compute_isodistance(lat, lng, size, options = {})
    Planner::Application.config.router.isoline(default_url, mode, :distance, lat, lng, size, sanitize_options(options))
  end

  private

  def default_url
    url || Planner::Application.config.router.url
  end

  def sanitize_options(options, extra_options = {})
    if !avoid_zones? && !speed_multiplier_zones?
      options.delete(:speed_multiplier_areas)
      options.delete(:area)
    end
    options[:speed_multiplier] = options.delete(:speed_multiplicator) if options[:speed_multiplicator] && !options[:speed_multiplier]
    options
  end
end
