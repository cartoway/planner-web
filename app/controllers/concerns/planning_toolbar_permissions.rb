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

# Toolbar visibility / usability for planning and route operations (ids from Preferences::Catalog operations JSON).
module PlanningToolbarPermissions
  extend ActiveSupport::Concern

  private

  def planning_api_web_callback_context?
    controller_path.start_with?('api_web/') || request.referer&.match('api-web').present?
  end

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

  # PlanningsController before_action: block optimize / optimize_route when the matching toolbar operation is not usable.
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

  # Call after @manage_planning and @planning are set. Mutates @manage_planning and @callback_button.
  def apply_planning_toolbar_operation_flags!
    return unless @planning && current_user

    planning_op_visible = method(:planning_operation_visible?)
    planning_op_disabled = method(:planning_operation_disabled?)

    @callback_button = planning_api_web_callback_context? &&
                       planning_op_visible.call('external_callback') &&
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
  end

  # Per-route header tools (operations.route). Depends on planning toolbar flags having been applied first.
  def apply_route_toolbar_operation_flags!
    return unless current_user

    route_op_visible = method(:route_operation_visible?)
    route_op_disabled = method(:route_operation_disabled?)

    route_export_visible = route_op_visible.call('export')
    @manage_planning[:disable_route_export] = route_op_disabled.call('export')
    manage_export = @manage_planning[:manage_export]
    manage_print = @manage_planning[:manage_print]
    @manage_planning[:manage_route_export_menu] = route_export_visible && manage_export
    @manage_planning[:manage_route_export_print_only] = route_export_visible && !manage_export && manage_print

    @manage_planning[:manage_route_optimize] = route_op_visible.call('optimize')
    @manage_planning[:disable_route_optimize] = route_op_disabled.call('optimize')

    @manage_planning[:manage_route_stops] = route_op_visible.call('stops')
    @manage_planning[:disable_route_stops] = route_op_disabled.call('stops')

    @manage_planning[:manage_route_view] = route_op_visible.call('view')
    @manage_planning[:disable_route_view] = route_op_disabled.call('view')

    route_vehicle_usage_operation_visible = route_op_visible.call('vehicle_usage')
    form_ok = !current_user.respond_to?(:form_visible?) || current_user.form_visible?(:vehicle_usages)
    @manage_planning[:manage_route_vehicle_usage] =
      route_vehicle_usage_operation_visible && @manage_planning[:manage_vehicle] && form_ok
    form_update_ok = !current_user.respond_to?(:form_update?) || current_user.form_update?(:vehicle_usages)
    @manage_planning[:disable_route_vehicle_usage] = route_op_disabled.call('vehicle_usage') || !form_update_ok
  end

  def apply_stop_toolbar_operation_flags!
    return unless current_user

    stop_op_visible = method(:stop_operation_visible?)
    stop_op_disabled = method(:stop_operation_disabled?)

    @manage_planning[:manage_stop_active] = stop_op_visible.call('active_stop')
    @manage_planning[:disable_stop_active] = stop_op_disabled.call('active_stop')

    @manage_planning[:manage_stop_move] = stop_op_visible.call('move_stop')
    @manage_planning[:disable_stop_move] = stop_op_disabled.call('move_stop')

    @manage_planning[:manage_stop_lock] = stop_op_visible.call('lock_stop')
    @manage_planning[:disable_stop_lock] = stop_op_disabled.call('lock_stop')
  end
end
