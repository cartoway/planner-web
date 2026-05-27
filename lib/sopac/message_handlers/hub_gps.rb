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

module SopacBroker
  module MessageHandlers
    class HubGps
      def self.call(customer_id, body)
        points = JSON.parse(body)
        points = [points] unless points.is_a?(Array)
        return if points.empty?

        cache = Cache.new(customer_id)
        points.group_by { |p| p['id'] }.each do |hub_id, hub_points|
          next if hub_id.blank?

          latest = hub_points.max_by { |p| (p['deviceTime'] || p['createdAt']).to_i }
          cache.write_hub_gps(hub_id, latest)
        end
      end
    end
  end
end
