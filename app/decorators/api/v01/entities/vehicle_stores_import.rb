# Copyright © Mapotempo, 2016
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
require_relative 'vehicle_store'

class V01::Entities::VehicleStoresImport < V01::Entities::StoresImport
  def self.entity_name
    'V01_VehicleStoreImport'
  end

  expose(:stores, using: V01::Entities::VehicleStore, documentation: { type: V01::Entities::VehicleStore, is_array: true, desc: 'In mutual exclusion with CSV file upload.', param_type: 'form'})
end
