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
    # Reads optional seeds from config/default_new_reseller_role.yml and config/default_permissions.yml (see initializers).
    module ConfigSeeds
      module_function

      def roles_hash
        h = Rails.application.config.try(:default_new_reseller_role_config)
        h.is_a?(Hash) ? h.deep_stringify_keys : {}
      end

      def permissions_defaults_hash
        h = Rails.application.config.try(:default_permissions_config)
        h.is_a?(Hash) ? h.deep_stringify_keys : {}
      end

      # nil => PlanningToolbar.default uses normalize({}) (disabled tier for all segments).
      def default_role_planning_toolbar_raw
        dr = roles_hash['default_role']
        return nil if dr.blank?

        dr.key?('planning_toolbar') ? dr['planning_toolbar'] : dr['operations']
      end

      # nil => use normalize_spaces({}).
      def default_role_spaces_raw
        dr = roles_hash['default_role']
        return nil if dr.blank?

        dr['spaces']
      end

      def no_role_planning_toolbar_raw
        nr = permissions_defaults_hash['no_role']
        return nil if nr.blank?

        nr.key?('planning_toolbar') ? nr['planning_toolbar'] : nr['operations']
      end

      def no_role_spaces_raw
        nr = permissions_defaults_hash['no_role']
        return nil if nr.blank?

        nr['spaces']
      end

      def new_role_planning_toolbar_raw
        nr = permissions_defaults_hash['new_role']
        return nil if nr.blank?

        nr.key?('planning_toolbar') ? nr['planning_toolbar'] : nr['operations']
      end

      def new_role_spaces_raw
        nr = permissions_defaults_hash['new_role']
        return nil if nr.blank?

        nr['spaces']
      end
    end
  end
end
