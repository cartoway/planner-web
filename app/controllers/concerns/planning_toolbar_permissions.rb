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

module PlanningToolbarPermissions
  extend ActiveSupport::Concern

  include PlanningToolbarOperationChecks
  include PlanningToolbarRouteStopFlags
  include PlanningToolbarPlanningFlags

  included do
    helper_method :planning_external_callback_json_partial?, :planning_external_callback_segment_disabled? if respond_to?(:helper_method)
  end

  def planning_external_callback_json_partial?
    return false unless @planning

    planning_operation_visible?('external_callback') &&
      @planning.customer.enable_external_callback? &&
      @planning.customer.external_callback_url.present?
  end

  def planning_external_callback_segment_disabled?
    return true unless planning_external_callback_json_partial?

    planning_operation_disabled?('external_callback')
  end
end
