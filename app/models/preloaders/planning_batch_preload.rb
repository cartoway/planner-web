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
module Preloaders
  # Per-batch association preload for Planning records.
  # Prefer BatchAssociationPreload on each batch instead of
  # relation.preload / scope.preload + find_each (Rails 6 limitations).
  module PlanningBatchPreload
    # Same tree as Planning#preload_route_details, plus :tags (visit_filling / tags_compatible?).
    ASSOCIATIONS = [
      :tags,
      { routes: Planning::ROUTE_DETAILS_ROUTE_PRELOAD },
      { vehicle_usage_set: Planning::VEHICLE_USAGE_SET_PRELOAD }
    ].freeze

    def self.preload!(records, associations: ASSOCIATIONS)
      BatchAssociationPreload.preload!(records, associations)
    end

    # Yields each batch after preloading associations.
    def self.each_batch(relation, batch_size: 30, associations: ASSOCIATIONS, &block)
      BatchAssociationPreload.each_batch(relation, associations: associations, batch_size: batch_size, &block)
    end
  end
end
