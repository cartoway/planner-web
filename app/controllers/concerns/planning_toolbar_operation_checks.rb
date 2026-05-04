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

# Visibility / usability helpers for planning, route, and stop toolbar segments (operations JSON).
module PlanningToolbarOperationChecks
  extend ActiveSupport::Concern

  private

  def planning_operation_visible?(operation_id)
    return true unless current_user.respond_to?(:operation_segment_visible?)

    current_user.operation_segment_visible?(:planning, operation_id)
  end

  def planning_operation_usable?(operation_id)
    return true unless current_user.respond_to?(:operation_segment_usable?)

    current_user.operation_segment_usable?(:planning, operation_id)
  end

  def planning_operation_disabled?(operation_id)
    planning_operation_visible?(operation_id) && !planning_operation_usable?(operation_id)
  end

  def route_operation_visible?(operation_id)
    return true unless current_user.respond_to?(:operation_segment_visible?)

    current_user.operation_segment_visible?(:route, operation_id)
  end

  def route_operation_usable?(operation_id)
    return true unless current_user.respond_to?(:operation_segment_usable?)

    current_user.operation_segment_usable?(:route, operation_id)
  end

  def route_operation_disabled?(operation_id)
    route_operation_visible?(operation_id) && !route_operation_usable?(operation_id)
  end

  def stop_operation_visible?(operation_id)
    return true if current_user.try(:admin?)
    return true unless current_user.respond_to?(:operation_segment_visible?)

    current_user.operation_segment_visible?(:stop, operation_id)
  end

  def stop_operation_usable?(operation_id)
    return true if current_user.try(:admin?)
    return true unless current_user.respond_to?(:operation_segment_usable?)

    current_user.operation_segment_usable?(:stop, operation_id)
  end

  def stop_operation_disabled?(operation_id)
    stop_operation_visible?(operation_id) && !stop_operation_usable?(operation_id)
  end

  def enforce_operation_usable_for_refresh!
    return if planning_operation_usable?('refresh')

    head :forbidden
  end

  def enforce_operation_usable_for_optimize!
    usable =
      if action_name == 'optimize_route'
        route_operation_usable?('optimize')
      else
        planning_operation_usable?('optimize')
      end
    return if usable

    head :forbidden
  end
end
