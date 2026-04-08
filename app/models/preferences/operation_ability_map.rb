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
  # Maps controller actions (CanCan subjects) to operations toolbar items (zone + tool id).
  # Used by Ability to deny access when the segment is not usable for the current user.
  module OperationAbilityMap
    # Each rule: can? action on model is denied when !user.operation_segment_usable?(zone, segment).
    RULES = [
      { model: Planning, actions: %i[optimize optimize_route], zone: :planning, segment: 'optimize' },
      { model: Planning, actions: %i[apply_zonings], zone: :planning, segment: 'zoning' },
      { model: Route, actions: %i[optimize], zone: :route, segment: 'optimize' }
    ].freeze

    def self.apply_cannot_rules!(ability, user)
      return if user.blank? || user.admin?
      return unless user.respond_to?(:operation_segment_usable?)

      RULES.each do |rule|
        ability.cannot rule[:actions], rule[:model] do |record|
          next false if record.nil?

          !user.operation_segment_usable?(rule[:zone], rule[:segment])
        end
      end
    end
  end
end
