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

# Maps planning toolbar segment permissions onto @manage_planning for the planning UI.
module PlanningToolbarPlanningFlags
  extend ActiveSupport::Concern

  private

  def apply_planning_toolbar_operation_flags!
    return unless @planning && current_user

    planning_op_visible = method(:planning_operation_visible?)
    planning_op_disabled = method(:planning_operation_disabled?)

    @callback_button = planning_op_visible.call('external_callback') &&
                       @planning.customer.enable_external_callback? &&
                       @planning.customer.external_callback_url.present?

    @manage_planning[:disable_external_callback] = planning_op_disabled.call('external_callback')

    if @manage_planning.key?(:manage_zoning)
      @manage_planning[:manage_zoning] &&= planning_op_visible.call('zoning')
    end
    @manage_planning[:disable_zoning] = planning_op_disabled.call('zoning')

    if @manage_planning.key?(:manage_vehicle_usage_set)
      @manage_planning[:manage_vehicle_usage_set] &&= planning_op_visible.call('vehicle_usage_set')
    end
    @manage_planning[:disable_vehicle_usage_set] = planning_op_disabled.call('vehicle_usage_set')

    @manage_planning[:manage_optimize] = planning_op_visible.call('optimize')
    @manage_planning[:disable_optimize] = planning_op_disabled.call('optimize')

    @manage_planning[:manage_refresh] = planning_op_visible.call('refresh')
    @manage_planning[:disable_refresh] = planning_op_disabled.call('refresh')

    @manage_planning[:manage_toggle_routes] = planning_op_visible.call('toggle_routes')
    @manage_planning[:disable_toggle_routes] = planning_op_disabled.call('toggle_routes')

    @manage_planning[:manage_toggle_route_data] = planning_op_visible.call('toggle_route_data')
    @manage_planning[:disable_toggle_route_data] = planning_op_disabled.call('toggle_route_data')

    @manage_planning[:manage_lock_routes] = planning_op_visible.call('lock_routes')
    @manage_planning[:disable_lock_routes] = planning_op_disabled.call('lock_routes')

    if @manage_planning.key?(:manage_export)
      @manage_planning[:manage_export] &&= planning_op_visible.call('export')
    end
    if @manage_planning.key?(:manage_print)
      @manage_planning[:manage_print] &&= planning_op_visible.call('export')
    end
    @manage_planning[:disable_planning_export] = planning_op_disabled.call('export')

    apply_route_toolbar_operation_flags!
    apply_stop_toolbar_operation_flags!

    @manage_planning[:planning_move_stops_visible] = @manage_planning[:manage_route_stops]
    @manage_planning[:planning_move_stops_usable] = @manage_planning[:manage_route_stops] && !@manage_planning[:disable_route_stops]

    @manage_planning[:send_stop_to_route_visible] = @manage_planning[:manage_stop_move]
    @manage_planning[:send_stop_to_route_usable] = @manage_planning[:manage_stop_move] && !@manage_planning[:disable_stop_move]

    @manage_planning[:manage_activate_stops] =
      planning_op_visible.call('activate_stops') && @manage_planning[:manage_stop_active]
    @manage_planning[:disable_activate_stops] =
      planning_op_disabled.call('activate_stops') || @manage_planning[:disable_stop_active]
  end
end
