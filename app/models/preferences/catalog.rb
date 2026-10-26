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

# Canonical ids for display preferences (headers, planning toolbar, spaces).
# User stores headers; Role stores planning_toolbar + spaces (resource permissions).
# Implementation is split under preferences/catalog/* for maintainability.
module Preferences
  module Catalog
    HEADER_PLANNING = Headers::HEADER_PLANNING
    HEADER_ROUTE = Headers::HEADER_ROUTE
    HEADER_PLANNING_DEFAULT = Headers::HEADER_PLANNING_DEFAULT
    HEADER_ROUTE_DEFAULT = Headers::HEADER_ROUTE_DEFAULT
    STOP_LIST_MAX_ACTIVE = StopList::MAX_ACTIVE
    DESTINATIONS_LIST_MAX_ACTIVE = DestinationsList::MAX_ACTIVE
    PLANNING_TOOLBAR_GROUPS_PLANNING = PlanningToolbar::GROUPS_PLANNING
    PLANNING_TOOLBAR_GROUPS_ROUTE = PlanningToolbar::GROUPS_ROUTE
    PLANNING_TOOLBAR_GROUPS_STOP = PlanningToolbar::GROUPS_STOP
    SPACE_KEYS = Spaces::SPACE_KEYS
    SPACE_ACTIONS = Spaces::SPACE_ACTIONS
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

      def normalize_headers(raw, customer: nil)
        Headers.normalize_headers(raw, customer: customer)
      end

      def normalize_destinations_index(raw)
        Headers.normalize_destinations_index(raw)
      end

      def normalize_stop_list_zone(raw)
        StopList.normalize_zone(raw)
      end

      def normalize_destinations_list_zone(raw, customer: nil)
        DestinationsList.normalize_zone(raw, customer: customer)
      end

      def destinations_list_allowed_column_ids(customer)
        DestinationsList.allowed_column_ids(customer)
      end

      def stop_list_field_value(stop, field_id)
        StopList.field_value(stop, field_id)
      end

      def default_planning_toolbar
        PlanningToolbar.default
      end

      def baseline_role_planning_toolbar_json
        PlanningToolbar.baseline_role_json
      end

      def baseline_role_spaces_json
        raw = ConfigSeeds.default_role_spaces_raw
        raw.nil? ? normalize_spaces({}) : normalize_spaces(raw.is_a?(Hash) ? raw.stringify_keys : {})
      end

      def new_role_admin_planning_toolbar_seed
        raw = ConfigSeeds.new_role_planning_toolbar_raw
        (raw.nil? ? PlanningToolbar.default : normalize_planning_toolbar(raw.is_a?(Hash) ? raw.stringify_keys : {})).deep_dup
      end

      def new_role_admin_spaces_seed
        raw = ConfigSeeds.new_role_spaces_raw
        (raw.nil? ? default_spaces : normalize_spaces(raw.is_a?(Hash) ? raw.stringify_keys : {})).deep_dup
      end

      def no_role_planning_toolbar_seed_hash
        raw = ConfigSeeds.no_role_planning_toolbar_raw
        raw.nil? ? {} : (raw.is_a?(Hash) ? raw.stringify_keys : {})
      end

      def no_role_spaces_seed_hash
        raw = ConfigSeeds.no_role_spaces_raw
        raw.nil? ? {} : (raw.is_a?(Hash) ? raw.stringify_keys : {})
      end

      def normalize_zone(zone_hash, allowed_ids)
        PlanningToolbar.normalize_zone(zone_hash, allowed_ids)
      end

      def normalize_planning_toolbar(raw)
        PlanningToolbar.normalize(raw)
      end

      def normalize_stop_zone(zone_hash)
        PlanningToolbar.normalize_stop_zone(zone_hash)
      end

      def merge_planning_toolbar_zone_from_three_columns_dragndrop(zone_existing, allowed_ids, active_ordered_ids, disabled_ordered_ids, hidden_ordered_ids = nil)
        PlanningToolbar.merge_zone_from_three_columns_dragndrop(zone_existing, allowed_ids, active_ordered_ids, disabled_ordered_ids, hidden_ordered_ids)
      end

      def merge_planning_toolbar_with_params(base_ops, raw_params)
        PlanningToolbar.merge_with_params(base_ops, raw_params)
      end

      def default_spaces
        Spaces.default_spaces
      end

      def normalize_spaces(raw)
        Spaces.normalize_spaces(raw)
      end

      def merge_spaces_with_params(base_spaces, raw_hash)
        Spaces.merge_spaces_with_params(base_spaces, raw_hash)
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
