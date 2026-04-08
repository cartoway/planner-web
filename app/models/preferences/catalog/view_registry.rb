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
module Preferences
  module Catalog
    # Maps catalog ids to edit UI partial paths (single source for planning/route heads + toolbars).
    module ViewRegistry
      # Subset of OPERATION_GROUPS_PLANNING rendered in #global_tools .pull-right.btn-group on planning edit.
      PLANNING_EDIT_GLOBAL_TOOLBAR_OPERATION_IDS = %w[toggle_routes toggle_route_data lock_routes export].freeze

      module_function

      def planning_edit_global_toolbar_operation_ids
        PLANNING_EDIT_GLOBAL_TOOLBAR_OPERATION_IDS
      end

      # @return [String, nil] e.g. "plannings/data_blocks/stops" or "routes/data_blocks/distance"
      def header_block_partial(zone, key)
        k = key.to_s
        allowed = zone.to_s == 'route' ? Headers::HEADER_ROUTE : Headers::HEADER_PLANNING
        return nil unless allowed.include?(k)

        zone.to_s == 'route' ? "routes/data_blocks/#{k}" : "plannings/data_blocks/#{k}"
      end

      # @return [String, nil] e.g. "plannings/operations/export" or "routes/operations/optimize"
      def toolbar_operation_partial(zone, operation_id)
        oid = operation_id.to_s
        allowed = zone.to_s == 'route' ? Operations::OPERATION_GROUPS_ROUTE : Operations::OPERATION_GROUPS_PLANNING
        return nil unless allowed.include?(oid)

        if zone.to_s == 'route'
          "routes/operations/#{oid}"
        else
          "plannings/operations/#{oid}"
        end
      end
    end
  end
end
