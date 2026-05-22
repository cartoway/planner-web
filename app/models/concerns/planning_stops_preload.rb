# frozen_string_literal: true

# Copyright © Cartoway, 2026
#
# This file is part of Cartoway Planner.
#
# Cartoway Planner is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Cartoway Planner is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Cartoway Planner. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#

module PlanningStopsPreload
  STOPS_PRELOAD_FIXED_THRESHOLD = 1000

  module_function

  def visible_stops_count(planning)
    planning.routes
            .select { |route| !route.hidden || !route.locked }
            .sum { |route| route.route_data&.stops_size.to_i }
  end

  def preload_thresholds(planning)
    limit = planning.customer.stops_preload_limit
    {
      low: [STOPS_PRELOAD_FIXED_THRESHOLD, limit].min,
      high: [STOPS_PRELOAD_FIXED_THRESHOLD, limit].max
    }
  end

  def preload_mode(planning)
    count = visible_stops_count(planning)
    thresholds = preload_thresholds(planning)

    if count < thresholds[:low]
      :full
    elsif count < thresholds[:high]
      :continuous
    else
      :manual
    end
  end

  def preload_stops?(planning)
    preload_mode(planning) == :full
  end
end
