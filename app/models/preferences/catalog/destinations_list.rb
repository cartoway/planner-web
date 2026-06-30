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
    # User-level destinations index list columns (v2 sidebar table).
    module DestinationsList
      COLUMN_IDS = %w[name address ref geocoding comment phone_number tags visit_tags visits].freeze
      DEFAULT_ACTIVE = %w[name address ref geocoding visits].freeze

      module_function

      def column_available?(id, customer)
        case id.to_s
        when 'ref' then customer.enable_references?
        when 'visit_tags', 'visits' then customer.is_editable?
        else true
        end
      end

      def allowed_column_ids(customer)
        COLUMN_IDS.select { |id| column_available?(id, customer) }
      end

      def default_active_for(customer)
        DEFAULT_ACTIVE.select { |id| column_available?(id, customer) }
      end

      def default_zone(customer = nil)
        allowed = customer ? allowed_column_ids(customer) : COLUMN_IDS
        active = (customer ? default_active_for(customer) : DEFAULT_ACTIVE.dup)
        {
          'active' => Core.filter_order(active, allowed),
          'hidden' => allowed - Core.filter_order(active, allowed)
        }
      end

      def normalize_zone(raw, customer: nil)
        allowed = customer ? allowed_column_ids(customer) : COLUMN_IDS
        default_active = customer ? default_active_for(customer) : DEFAULT_ACTIVE.dup
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
    end
  end
end
