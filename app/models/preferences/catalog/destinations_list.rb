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
      COLUMN_IDS = %w[name street postalcode city ref geocoding comment phone_number tags visit_ref visit_tags].freeze
      VISIT_SCOPED_COLUMN_IDS = %w[visit_ref visit_tags].freeze
      DEFAULT_ACTIVE = %w[name street postalcode city ref geocoding visit_ref].freeze
      DELIVERABLE_UNIT_COLUMN_PREFIX = 'deliverable_unit_'

      module_function

      def deliverable_unit_column_id(unit)
        "#{DELIVERABLE_UNIT_COLUMN_PREFIX}#{unit.id}"
      end

      def deliverable_unit_column_id?(column_id)
        column_id.to_s.start_with?(DELIVERABLE_UNIT_COLUMN_PREFIX)
      end

      def visit_scoped_column?(column_id)
        id = column_id.to_s
        VISIT_SCOPED_COLUMN_IDS.include?(id) || deliverable_unit_column_id?(id)
      end

      def parse_deliverable_unit_column_id(column_id)
        return nil unless deliverable_unit_column_id?(column_id)

        column_id.to_s.delete_prefix(DELIVERABLE_UNIT_COLUMN_PREFIX).to_i
      end

      def deliverable_units_columns_available?(customer)
        customer.deliverable_units.any?
      end

      def deliverable_unit_column_ids(customer)
        return [] unless deliverable_units_columns_available?(customer)

        customer.deliverable_units.map { |unit| deliverable_unit_column_id(unit) }
      end

      def column_available?(id, customer)
        du_id = parse_deliverable_unit_column_id(id)
        if du_id
          return customer.deliverable_units.any? { |unit| unit.id == du_id }
        end

        case id.to_s
        when 'ref' then customer.enable_references?
        when 'visit_tags', 'visit_ref' then customer.is_editable?
        else true
        end
      end

      def allowed_column_ids(customer)
        COLUMN_IDS.select { |id| column_available?(id, customer) } + deliverable_unit_column_ids(customer)
      end

      def default_active_for(customer)
        static = DEFAULT_ACTIVE.select { |id| column_available?(id, customer) }
        static + deliverable_unit_column_ids(customer)
      end

      def default_zone(customer = nil)
        allowed = customer ? allowed_column_ids(customer) : COLUMN_IDS
        active = (customer ? default_active_for(customer) : DEFAULT_ACTIVE.dup)
        {
          'active' => Core.filter_order(active, allowed),
          'hidden' => allowed - Core.filter_order(active, allowed)
        }
      end

      def remap_legacy_column_ids(ids)
        ids.flat_map do |id|
          case id.to_s
          when 'address' then %w[street postalcode city]
          when 'visits' then %w[visit_ref]
          else id.to_s
          end
        end.uniq
      end

      def normalize_zone(raw, customer: nil)
        allowed = customer ? allowed_column_ids(customer) : COLUMN_IDS
        default_active = customer ? default_active_for(customer) : DEFAULT_ACTIVE.dup
        z = raw.is_a?(Hash) ? raw.stringify_keys : {}
        active = Core.filter_order(remap_legacy_column_ids(z['active'] || []), allowed)
        hidden_src = Core.filter_order(remap_legacy_column_ids(z['hidden'] || []), allowed)
        active.uniq!
        hidden_src.uniq!
        hidden_src -= active
        if active.empty?
          active = Core.filter_order(default_active, allowed)
        end
        if customer
          deliverable_unit_column_ids(customer).each do |id|
            next if active.include?(id) || hidden_src.include?(id)

            active << id
          end
          active = Core.filter_order(active, allowed)
        end
        missing_hidden = allowed.reject { |id| active.include?(id) }
        hidden_ordered = (hidden_src & missing_hidden) + (missing_hidden - hidden_src).sort_by { |id| allowed.index(id) }
        { 'active' => ensure_visit_ref_before_visit_tags(active), 'hidden' => hidden_ordered }
      end

      def ensure_visit_ref_before_visit_tags(ids)
        return ids unless ids.include?('visit_ref') && ids.include?('visit_tags')

        ref_index = ids.index('visit_ref')
        tags_index = ids.index('visit_tags')
        return ids if ref_index < tags_index

        ids = ids.dup
        ids.delete('visit_ref')
        ids.insert(ids.index('visit_tags'), 'visit_ref')
      end
    end
  end
end
