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
    # Planning / route operation toolbar (ordered tool ids + per-tool segment_controls in JSON).
    module Operations
      OPERATION_GROUPS_PLANNING = %w[
        external_callback optimize zoning vehicle_usage_set toggle_routes toggle_route_data lock_routes export refresh
      ].freeze

      OPERATION_GROUPS_ROUTE = %w[
        vehicle_usage optimize stops view export
      ].freeze

      OPERATION_GROUPS_STOP = %w[
        active_stop
        move_stop
        lock_stop
      ].freeze

      # Missing segment_controls entries in normalize_zone / normalize_stop_zone (disabled tier: visible, not usable).
      NORMALIZE_SEGMENT_VISIBLE_DEFAULT = true
      NORMALIZE_SEGMENT_USABLE_DEFAULT = false

      module_function

      # Full toolbar seed when +new_role.operations+ is null in default_permissions.yml: same source as
      # config/default_new_reseller_role.yml (+default_role.operations+). If that YAML omits operations,
      # falls back to normalize_operations({}) (disabled tier for all zones).
      def default_operations
        raw = Preferences::Catalog::ConfigSeeds.default_role_operations_raw
        normalize_operations(raw.is_a?(Hash) ? raw.stringify_keys : {})
      end

      def normalize_stop_zone(zone_hash)
        zh = zone_hash.is_a?(Hash) ? zone_hash.stringify_keys : {}
        segments = Core.filter_order(zh['segments'], OPERATION_GROUPS_STOP)
        segments = OPERATION_GROUPS_STOP.dup if segments.empty?

        controls = zh['segment_controls'].is_a?(Hash) ? zh['segment_controls'].stringify_keys : {}
        segment_controls = {}
        OPERATION_GROUPS_STOP.each do |id|
          c = controls[id].is_a?(Hash) ? controls[id].stringify_keys : {}
          segment_controls[id] = {
            'visible' => Core.truthy?(c.fetch('visible', NORMALIZE_SEGMENT_VISIBLE_DEFAULT)),
            'usable' => Core.truthy?(c.fetch('usable', NORMALIZE_SEGMENT_USABLE_DEFAULT))
          }
        end

        { 'segments' => segments, 'segment_controls' => segment_controls }
      end

      def normalize_zone(zone_hash, allowed_ids)
        zh = zone_hash.is_a?(Hash) ? zone_hash.stringify_keys : {}
        segments = Core.filter_order(zh['segments'], allowed_ids)
        segments = allowed_ids.dup if segments.empty?

        controls = zh['segment_controls'].is_a?(Hash) ? zh['segment_controls'].stringify_keys : {}
        segment_controls = {}
        allowed_ids.each do |id|
          c = controls[id].is_a?(Hash) ? controls[id].stringify_keys : {}
          segment_controls[id] = {
            'visible' => Core.truthy?(c.fetch('visible', NORMALIZE_SEGMENT_VISIBLE_DEFAULT)),
            'usable' => Core.truthy?(c.fetch('usable', NORMALIZE_SEGMENT_USABLE_DEFAULT))
          }
        end

        { 'segments' => segments, 'segment_controls' => segment_controls }
      end

      def normalize_operations(raw)
        ops = raw.is_a?(Hash) ? raw.stringify_keys : {}
        {
          'planning' => normalize_zone(ops['planning'], OPERATION_GROUPS_PLANNING),
          'route' => normalize_zone(ops['route'], OPERATION_GROUPS_ROUTE),
          'stop' => normalize_stop_zone(ops['stop'])
        }
      end

      # Reseller system default role toolbar JSON from config/default_new_reseller_role.yml (+default_role.operations+).
      # When +operations+ is absent or null (no usable config), falls back to normalize_operations({}) — all catalog
      # segments listed with the disabled tier (visible, not usable); see NORMALIZE_SEGMENT_* defaults.
      def baseline_role_operations_json
        raw = Preferences::Catalog::ConfigSeeds.default_role_operations_raw
        raw.nil? ? normalize_operations({}) : normalize_operations(raw.is_a?(Hash) ? raw.stringify_keys : {})
      end

      def merge_operations_zone_from_three_columns_dragndrop(_zone_existing, allowed_ids, active_ordered_ids, disabled_ordered_ids, hidden_ordered_ids = nil)
        active_filtered = Core.filter_order(active_ordered_ids, allowed_ids)
        disabled_filtered = Core.filter_order(disabled_ordered_ids, allowed_ids)
        disabled_filtered -= active_filtered
        hidden_ids = if hidden_ordered_ids.nil?
                       allowed_ids - active_filtered - disabled_filtered
                     else
                       listed = Core.filter_order(Array.wrap(hidden_ordered_ids), allowed_ids) - active_filtered - disabled_filtered
                       placed = active_filtered + disabled_filtered + listed
                       listed + (allowed_ids - placed)
                     end
        merged_segments = active_filtered + disabled_filtered + hidden_ids

        segment_controls = {}
        allowed_ids.each do |id|
          in_active = active_filtered.include?(id)
          in_disabled = disabled_filtered.include?(id)
          segment_controls[id] = {
            'visible' => in_active || in_disabled,
            'usable' => in_active
          }
        end

        normalize_zone({ 'segments' => merged_segments, 'segment_controls' => segment_controls }, allowed_ids)
      end

      # Merges admin drag-and-drop params (role[operations][planning], *_disabled, route, …) into stored operations JSON.
      def merge_operations_with_params(base_ops, raw_params)
        out = base_ops.deep_dup.deep_stringify_keys
        ph = raw_params.respond_to?(:to_unsafe_h) ? raw_params.to_unsafe_h : raw_params.to_h
        ph = ph.stringify_keys
        %w[planning route stop].each do |zone|
          disabled_key = "#{zone}_disabled"
          hidden_key = "#{zone}_hidden"
          next unless ph.key?(zone) || ph.key?(disabled_key) || ph.key?(hidden_key)

          allowed = case zone
                    when 'route' then OPERATION_GROUPS_ROUTE
                    when 'stop' then OPERATION_GROUPS_STOP
                    else OPERATION_GROUPS_PLANNING
                    end
          disabled_ids = Array.wrap(ph[disabled_key]).compact
          hidden_ids_param = ph.key?(hidden_key) ? Array.wrap(ph[hidden_key]) : nil
          out[zone] = merge_operations_zone_from_three_columns_dragndrop(
            out[zone] || {},
            allowed,
            Array.wrap(ph[zone]),
            disabled_ids,
            hidden_ids_param
          )
        end
        normalize_operations(out)
      end
    end
  end
end
