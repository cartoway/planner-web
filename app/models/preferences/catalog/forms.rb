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
    # forms.* resource visibility / usability (admin DnD).
    module Forms
      FORM_RESOURCES = %w[plannings destinations visits vehicle_usages stores].freeze

      # Missing per-resource entries in normalize_forms (disabled tier: visible, not usable).
      NORMALIZE_FORM_VISIBLE_DEFAULT = true
      NORMALIZE_FORM_USABLE_DEFAULT = false

      module_function

      def default_forms
        FORM_RESOURCES.index_with do |_key|
          { 'visible' => true, 'usable' => true }
        end
      end

      def normalize_forms(raw)
        return default_forms if raw.blank? || !raw.is_a?(Hash)

        str = raw.stringify_keys
        out = {}
        seen = []

        str.each do |key, entry|
          next unless FORM_RESOURCES.include?(key)

          seen << key
          e = entry.is_a?(Hash) ? entry.stringify_keys : {}
          out[key] = {
            'visible' => Core.truthy?(e.fetch('visible', NORMALIZE_FORM_VISIBLE_DEFAULT)),
            'usable' => Core.truthy?(e.fetch('usable', NORMALIZE_FORM_USABLE_DEFAULT))
          }
        end

        FORM_RESOURCES.each do |key|
          next if seen.include?(key)

          out[key] = {
            'visible' => Core.truthy?(NORMALIZE_FORM_VISIBLE_DEFAULT),
            'usable' => Core.truthy?(NORMALIZE_FORM_USABLE_DEFAULT)
          }
        end

        out
      end

      def forms_param_ids(raw_hash, key, allowed)
        rh = raw_hash.is_a?(Hash) ? raw_hash.stringify_keys : {}
        return [] unless rh.key?(key.to_s)

        Array.wrap(rh[key.to_s]).reject(&:blank?).map(&:to_s) & allowed
      end

      def merge_forms_with_params(_base_forms, raw_hash)
        allowed = FORM_RESOURCES
        rh = raw_hash.is_a?(Hash) ? raw_hash.stringify_keys : {}
        active = forms_param_ids(rh, 'forms_active', allowed)
        disabled = forms_param_ids(rh, 'forms_disabled', allowed)
        disabled -= active
        hidden_keys = allowed - active - disabled
        ordered_hash = {}
        (active + disabled + hidden_keys).each do |key|
          ordered_hash[key] = {
            'visible' => active.include?(key) || disabled.include?(key),
            'usable' => active.include?(key)
          }
        end
        normalize_forms(ordered_hash)
      end
    end
  end
end
