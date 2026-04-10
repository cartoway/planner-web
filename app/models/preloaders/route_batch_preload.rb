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
  module RouteBatchPreload
    SUMMARY_ASSOCIATIONS = [
      :route_data,
      :stops,
      { planning: { customer: :deliverable_units } },
      {
        vehicle_usage: [
          :tags,
          { vehicle: [:tags] }
        ]
      }
    ].freeze

    DETAIL_ASSOCIATIONS = [
      {
        stops: [
          :route_data,
          {
            visit: [
              :relation_currents,
              :relation_successors,
              :tags,
              {
                destination: [
                  :tags,
                  :visits,
                  { customer: :deliverable_units }
                ]
              }
            ]
          },
          { store_reload: [:store] },
          { store: [:customer] }
        ]
      },
      {
        vehicle_usage: [
          :store_start,
          :store_stop,
          :store_rest,
          :store_reloads,
          :tags,
          { vehicle_usage_set: [:store_start, :store_stop, :store_rest, :store_reloads] },
          { vehicle: [:router, :tags, { customer: [:router, :deliverable_units] }] }
        ]
      }
    ].freeze

    def self.associations_for(summary:)
      summary ? SUMMARY_ASSOCIATIONS : DETAIL_ASSOCIATIONS
    end

    def self.preload!(batch, summary:)
      BatchAssociationPreload.preload!(batch, associations_for(summary: summary))
    end
  end
end
