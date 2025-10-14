# Copyright © Cartoway, 2025
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

# Solution inspired by Evil Martians' "Rails after_commit everywhere"
# https://evilmartians.com/chronicles/rails-after_commit-everywhere
# This ensures background jobs are only enqueued after database transactions are committed
#
class V01::Entities::StoreReload < Grape::Entity
  def self.entity_name
    'V01_StoreReload'
  end

  expose(:id, documentation: { type: Integer })
  expose(:ref, documentation: { type: String })
  expose(:duration, documentation: { type: String })
  expose(:time_window_start, documentation: { type: String })
  expose(:time_window_end, documentation: { type: String })
end
