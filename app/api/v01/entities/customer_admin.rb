# Copyright © Mapotempo, 2014-2015
#
# This file is part of Mapotempo.
#
# Mapotempo is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Mapotempo is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Mapotempo. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#
class V01::Entities::CustomerAdmin < V01::Entities::Customer
  def self.entity_name
    'V01_CustomerAdmin'
  end
  EDIT_ONLY_ADMIN = 'Only available in admin.'.freeze

  # expose(:reseller_id, documentation: { type: Integer, desc: EDIT_ONLY_ADMIN })
  expose(:test, documentation: { type: 'Boolean', desc: 'Test account or not. ' + EDIT_ONLY_ADMIN })
  expose(:description, documentation: { type: String, desc: EDIT_ONLY_ADMIN })

  expose(:profile_id, documentation: { type: Integer, desc: EDIT_ONLY_ADMIN })

  expose(:enable_references, documentation: { type: 'Boolean', desc: 'Show references or not. ' + EDIT_ONLY_ADMIN })
  expose(:enable_global_optimization, documentation: { type: 'Boolean', desc: EDIT_ONLY_ADMIN })
  expose(:enable_vehicle_position, documentation: { type: 'Boolean', desc: EDIT_ONLY_ADMIN })
  expose(:enable_stop_status, documentation: { type: 'Boolean', desc: EDIT_ONLY_ADMIN })
  expose(:enable_sms, documentation: { type: 'Boolean', desc: EDIT_ONLY_ADMIN })

  expose(:max_vehicles, documentation: { type: Integer, desc: EDIT_ONLY_ADMIN })
  expose(:max_plannings, documentation: { type: Integer, desc: EDIT_ONLY_ADMIN })
  expose(:max_zonings, documentation: { type: Integer, desc: EDIT_ONLY_ADMIN })
  expose(:max_destinations, documentation: { type: Integer, desc: EDIT_ONLY_ADMIN })
  expose(:max_vehicle_usage_sets, documentation: { type: Integer, desc: EDIT_ONLY_ADMIN })
end
