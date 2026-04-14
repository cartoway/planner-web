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

# Canonical ids for display preferences (headers, operations toolbars, forms).
# User stores headers plus optional user-level operations/forms; Role stores operations/forms as assignable permissions.
# Implementation is split under preferences/catalog/* for maintainability.
module Preferences
  module Catalog
    HEADER_PLANNING = Headers::HEADER_PLANNING
    HEADER_ROUTE = Headers::HEADER_ROUTE
    HEADER_PLANNING_DEFAULT = Headers::HEADER_PLANNING_DEFAULT
    HEADER_ROUTE_DEFAULT = Headers::HEADER_ROUTE_DEFAULT
    OPERATION_GROUPS_PLANNING = Operations::OPERATION_GROUPS_PLANNING
    OPERATION_GROUPS_ROUTE = Operations::OPERATION_GROUPS_ROUTE
    OPERATION_GROUPS_STOP = Operations::OPERATION_GROUPS_STOP
    FORM_RESOURCES = Forms::FORM_RESOURCES
    DEFAULT_BOOL = Core::DEFAULT_BOOL

    class << self
      def truthy?(val)
        Core.truthy?(val)
      end

      def filter_order(list, allowed)
        Core.filter_order(list, allowed)
      end

      def default_headers
        Headers.default_headers
      end

      def header_zone_active_default(zone)
        Headers.header_zone_active_default(zone)
      end

      def normalize_header_zone(raw, allowed)
        Headers.normalize_header_zone(raw, allowed)
      end

      def normalize_headers(raw)
        Headers.normalize_headers(raw)
      end

      def default_operations
        Operations.default_operations
      end

      def zone_default(segment_ids)
        Operations.zone_default(segment_ids)
      end

      def normalize_zone(zone_hash, allowed_ids)
        Operations.normalize_zone(zone_hash, allowed_ids)
      end

      def normalize_operations(raw)
        Operations.normalize_operations(raw)
      end

      def normalize_stop_zone(zone_hash)
        Operations.normalize_stop_zone(zone_hash)
      end

      def merge_operations_zone_from_three_columns_dragndrop(zone_existing, allowed_ids, active_ordered_ids, disabled_ordered_ids, hidden_ordered_ids = nil)
        Operations.merge_operations_zone_from_three_columns_dragndrop(zone_existing, allowed_ids, active_ordered_ids, disabled_ordered_ids, hidden_ordered_ids)
      end

      def merge_operations_with_params(base_ops, raw_params)
        Operations.merge_operations_with_params(base_ops, raw_params)
      end

      def default_forms
        Forms.default_forms
      end

      def normalize_forms(raw)
        Forms.normalize_forms(raw)
      end

      def forms_param_ids(raw_hash, key, allowed)
        Forms.forms_param_ids(raw_hash, key, allowed)
      end

      def merge_forms_with_params(base_forms, raw_hash)
        Forms.merge_forms_with_params(base_forms, raw_hash)
      end

      def header_block_partial(zone, key)
        ViewRegistry.header_block_partial(zone, key)
      end

      def toolbar_operation_partial(zone, operation_id)
        ViewRegistry.toolbar_operation_partial(zone, operation_id)
      end

      def planning_edit_global_toolbar_operation_ids
        ViewRegistry.planning_edit_global_toolbar_operation_ids
      end
    end
  end
end
