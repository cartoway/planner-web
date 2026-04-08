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
    # Planning / route header metrics (edit head toolbar).
    module Headers
      HEADER_PLANNING = %w[
        stops duration distance total_revenue total_cost balance vehicles emission speed quantities
        wait_time visits_duration
      ].freeze

      HEADER_ROUTE = %w[
        stops duration distance total_revenue total_cost balance speed emission
        used_reloads quantities wait_time visits_duration
      ].freeze

      HEADER_PLANNING_DEFAULT = (HEADER_PLANNING - %w[wait_time visits_duration]).freeze
      HEADER_ROUTE_DEFAULT = (HEADER_ROUTE - %w[wait_time visits_duration]).freeze

      module_function

      def default_headers
        {
          'planning' => {
            'active' => HEADER_PLANNING_DEFAULT.dup,
            'hidden' => (HEADER_PLANNING - HEADER_PLANNING_DEFAULT).dup
          },
          'route' => {
            'active' => HEADER_ROUTE_DEFAULT.dup,
            'hidden' => (HEADER_ROUTE - HEADER_ROUTE_DEFAULT).dup
          }
        }
      end

      def header_zone_active_default(zone)
        zone.to_s == 'route' ? HEADER_ROUTE_DEFAULT.dup : HEADER_PLANNING_DEFAULT.dup
      end

      def normalize_header_zone(raw, allowed)
        default_active =
          allowed == HEADER_ROUTE ? HEADER_ROUTE_DEFAULT.dup : HEADER_PLANNING_DEFAULT.dup
        z = raw.is_a?(Hash) ? raw.stringify_keys : {}
        active = Core.filter_order(z['active'], allowed)
        hidden_src = Core.filter_order(z['hidden'], allowed)
        active.uniq!
        hidden_src.uniq!
        hidden_src -= active
        if active.empty?
          active = Core.filter_order(default_active, allowed)
        end
        missing_hidden = allowed.reject { |id| active.include?(id) }
        hidden_ordered = (hidden_src & missing_hidden) + (missing_hidden - hidden_src).sort_by { |id| allowed.index(id) }
        { 'active' => active, 'hidden' => hidden_ordered }
      end

      def normalize_headers(raw)
        h = raw.is_a?(Hash) ? raw.stringify_keys : {}
        {
          'planning' => normalize_header_zone(h['planning'], HEADER_PLANNING),
          'route' => normalize_header_zone(h['route'], HEADER_ROUTE)
        }
      end
    end
  end
end
