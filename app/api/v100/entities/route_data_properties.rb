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
class V100::Entities::RouteDataProperties < Grape::Entity
  def self.entity_name
    'V100_RouteDataProperties'
  end

  expose :id, documentation: { type: Integer }
  expose :hidden, documentation: { type: 'Boolean' }
  expose :color, documentation: { type: String, desc: 'Color code with #. For instance: #FF0000.' }

  expose :size_active, documentation: { type: Integer }
  expose :size_destinations, documentation: { type: Integer }
  expose :size_store_reloads, documentation: { type: Integer }
  expose :stops_size, documentation: { type: Integer }
  expose :no_geolocalization, documentation: { type: 'Boolean' }
  expose :no_path, documentation: { type: 'Boolean' }
  expose :out_of_capacity, documentation: { type: 'Boolean' }
  expose :out_of_drive_time, documentation: { type: 'Boolean' }
  expose :out_of_force_position, documentation: { type: 'Boolean' }
  expose :out_of_max_distance, documentation: { type: 'Boolean' }
  expose :out_of_max_reload, documentation: { type: 'Boolean' }
  expose :out_of_max_ride_distance, documentation: { type: 'Boolean' }
  expose :out_of_max_ride_duration, documentation: { type: 'Boolean' }
  expose :out_of_relation, documentation: { type: 'Boolean' }
  expose :out_of_skill, documentation: { type: 'Boolean' }
  expose :out_of_window, documentation: { type: 'Boolean' }
  expose :out_of_work_time, documentation: { type: 'Boolean' }
  expose :unmanageable_capacity, documentation: { type: 'Boolean' }
  expose :max_loads, documentation: { type: Hash, desc: 'Per deliverable unit id (jsonb).' }
end
