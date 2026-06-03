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

module PlanningStatisticsHelper
  def planning_statistics_routes(planning, sidebar_routes, user)
    sidebar = Array(sidebar_routes)
    return sidebar if user&.filter_planning_route_data

    planning.routes.includes_vehicle_usages.to_a
  end

  # Cumulative total_duration (incl. rests) and work_duration (excl. rests) for assigned routes.
  def planning_time_totals_for_routes(routes)
    duration_total = 0
    work_duration_total = 0

    Array(routes).each do |route|
      next unless route.vehicle_usage

      duration_total += route.total_duration
      work_duration_total += route.work_duration
    end

    { duration_total: duration_total, work_duration_total: work_duration_total }
  end
end
