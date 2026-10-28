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
    # Space access (visible/usable) + per-space action segments (admin DnD).
    # Role.spaces is the source of truth; Role.planning_toolbar stays toolbar-only.
    module Spaces # rubocop:disable Metrics/ModuleLength
      SPACE_KEYS = %w[
        plannings destination vehicle_usages stores tags customer
        deliverable_units custom_attributes operations
      ].freeze

      SPACE_ACTIONS = {
        'plannings' => %w[edit],
        'destination' => %w[edit delete_all_destinations delete_all_visits],
        'vehicle_usages' => %w[edit],
        'stores' => %w[edit],
        'tags' => %w[edit delete_visits_by_tags delete_destinations_by_tags],
        'customer' => %w[edit],
        'deliverable_units' => %w[edit],
        'custom_attributes' => %w[edit],
        'operations' => %w[sync transmit destroy export]
      }.freeze

      NORMALIZE_SPACE_VISIBLE_DEFAULT = true
      NORMALIZE_SPACE_USABLE_DEFAULT = false
      NORMALIZE_ACTION_VISIBLE_DEFAULT = true
      NORMALIZE_ACTION_USABLE_DEFAULT = false

      module_function

      def default_spaces
        SPACE_KEYS.index_with { |key| default_space_entry(key, visible: true, usable: true, actions_all_usable: true) }
      end

      def default_space_entry(key, visible:, usable:, actions_all_usable:)
        allowed = SPACE_ACTIONS.fetch(key)
        controls = allowed.index_with do |_aid|
          {
            'visible' => actions_all_usable || visible,
            'usable' => actions_all_usable && usable && visible
          }
        end
        {
          'visible' => visible,
          'usable' => usable && visible,
          'actions' => {
            'segments' => allowed.dup,
            'segment_controls' => controls
          }
        }
      end

      def normalize_spaces(raw)
        str = raw.is_a?(Hash) ? raw.stringify_keys : {}
        SPACE_KEYS.index_with { |key| normalize_space_entry(key, str[key]) }
      end

      def normalize_space_entry(key, entry)
        e = entry.is_a?(Hash) ? entry.stringify_keys : {}
        visible = Core.truthy?(e.fetch('visible', NORMALIZE_SPACE_VISIBLE_DEFAULT))
        usable = Core.truthy?(e.fetch('usable', NORMALIZE_SPACE_USABLE_DEFAULT))
        usable = false unless visible

        {
          'visible' => visible,
          'usable' => usable,
          'actions' => normalize_space_actions(key, e['actions'], space_visible: visible, space_usable: usable)
        }
      end

      def normalize_space_actions(key, raw_actions, space_visible:, space_usable:)
        allowed = SPACE_ACTIONS.fetch(key)
        zh = raw_actions.is_a?(Hash) ? raw_actions.stringify_keys : {}
        segments = Core.filter_order(zh['segments'], allowed)
        segments = allowed.dup if segments.empty?

        controls_in = zh['segment_controls'].is_a?(Hash) ? zh['segment_controls'].stringify_keys : {}
        segment_controls = {}
        allowed.each do |id|
          if controls_in[id].nil?
            # Opt-in: hide clear-all-visits until explicitly enabled (migration seeds the same).
            if key == 'destination' && id == 'delete_all_visits'
              vis = false
              use = false
            else
              vis = space_visible
              use = space_usable
            end
          else
            c = controls_in[id].is_a?(Hash) ? controls_in[id].stringify_keys : {}
            vis = Core.truthy?(c.fetch('visible', NORMALIZE_ACTION_VISIBLE_DEFAULT))
            use = Core.truthy?(c.fetch('usable', NORMALIZE_ACTION_USABLE_DEFAULT))
          end
          if !space_visible
            vis = false
            use = false
          elsif !space_usable
            use = false
            vis = true
          end
          segment_controls[id] = { 'visible' => vis, 'usable' => use && vis }
        end

        { 'segments' => segments, 'segment_controls' => segment_controls }
      end

      def spaces_param_ids(raw_hash, key, allowed)
        rh = raw_hash.is_a?(Hash) ? raw_hash.stringify_keys : {}
        return [] unless rh.key?(key.to_s)

        Array.wrap(rh[key.to_s]).reject(&:blank?).map(&:to_s) & allowed
      end

      def merge_spaces_with_params(base_spaces, raw_hash)
        allowed = SPACE_KEYS
        rh = raw_hash.is_a?(Hash) ? raw_hash.stringify_keys : {}
        base = normalize_spaces(base_spaces)

        active = spaces_param_ids(rh, 'spaces_active', allowed)
        disabled = spaces_param_ids(rh, 'spaces_disabled', allowed)
        disabled -= active
        hidden_keys = allowed - active - disabled

        out = {}
        (active + disabled + hidden_keys).each do |key|
          visible = active.include?(key) || disabled.include?(key)
          usable = active.include?(key)
          actions_raw = if usable
                          merge_space_actions_from_params(key, base.dig(key, 'actions'), rh)
                        else
                          base.dig(key, 'actions')
                        end
          out[key] = {
            'visible' => visible,
            'usable' => usable,
            'actions' => actions_raw
          }
        end
        normalize_spaces(out)
      end

      def merge_space_actions_from_params(space_key, existing_actions, raw_hash)
        allowed = SPACE_ACTIONS.fetch(space_key)
        actions_root = raw_hash['spaces_actions']
        actions_root = actions_root.to_unsafe_h if actions_root.respond_to?(:to_unsafe_h)
        actions_root = actions_root.is_a?(Hash) ? actions_root.stringify_keys : {}
        space_params = actions_root[space_key]
        space_params = space_params.to_unsafe_h if space_params.respond_to?(:to_unsafe_h)
        space_params = space_params.is_a?(Hash) ? space_params.stringify_keys : {}

        return existing_actions if space_params.blank?
        return existing_actions unless space_params.key?('active') || space_params.key?('disabled') || space_params.key?('hidden')

        active_filtered = Core.filter_order(Array.wrap(space_params['active']), allowed)
        disabled_filtered = Core.filter_order(Array.wrap(space_params['disabled']), allowed) - active_filtered
        hidden_filtered = if space_params.key?('hidden')
                            Core.filter_order(Array.wrap(space_params['hidden']), allowed) - active_filtered - disabled_filtered
                          else
                            allowed - active_filtered - disabled_filtered
                          end
        actions_from_tiers(allowed, active_filtered, disabled_filtered, hidden_filtered)
      end
      private_class_method :merge_space_actions_from_params

      def actions_from_tiers(allowed, active_ids, disabled_ids, hidden_ids)
        placed = active_ids + disabled_ids + hidden_ids
        segments = placed + (allowed - placed)
        controls = {}
        allowed.each do |id|
          in_active = active_ids.include?(id)
          in_disabled = disabled_ids.include?(id)
          controls[id] = {
            'visible' => in_active || in_disabled,
            'usable' => in_active
          }
        end
        { 'segments' => segments, 'segment_controls' => controls }
      end
      private_class_method :actions_from_tiers

      def space_action_usable_in?(space_entry, action_id)
        return false unless space_entry.is_a?(Hash)

        e = space_entry.stringify_keys
        return false unless Core.truthy?(e['visible']) && Core.truthy?(e['usable'])

        actions = e['actions'].is_a?(Hash) ? e['actions'].stringify_keys : {}
        controls = actions['segment_controls'].is_a?(Hash) ? actions['segment_controls'].stringify_keys : {}
        c = controls[action_id.to_s]
        return false unless c.is_a?(Hash)

        c = c.stringify_keys
        Core.truthy?(c['visible']) && Core.truthy?(c['usable'])
      end
    end
  end
end
