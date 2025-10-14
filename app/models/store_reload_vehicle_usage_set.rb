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

class StoreReloadVehicleUsageSet < ApplicationRecord
  belongs_to :store_reload, inverse_of: :store_reload_vehicle_usage_sets
  belongs_to :vehicle_usage_set, inverse_of: :store_reload_vehicle_usage_sets

  validates :store_reload_id, uniqueness: { scope: :vehicle_usage_set_id }
end
