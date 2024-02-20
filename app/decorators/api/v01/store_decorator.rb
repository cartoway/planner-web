# Copyright © Mapotempo, 2015-2016
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

def class_exists?(class_name)
  klass = Module.const_get(class_name)
  return klass.is_a?(Class)
rescue NameError
  return false
end

# all are not loaded during delayed_job run_process
if class_exists?('V01::Stores') && caller.none?{ |l| l =~ /bin\/delayed_job/ }
  require_relative 'entities/vehicle_stores_import'

  V01::Stores.class_eval do
    desc 'Import synchronously vehicle, vehicle_usage and store (with only one vehicle_usage_set present) by upload a CSV file or by JSON.',
      nickname: 'importVehicleStores',
      params: V01::Entities::VehicleStoresImport.documentation,
      is_array: true,
      entity: V01::Entities::VehicleStore
    put :import_vehicle_stores do

      import = if params[:stores]
        ImportJson.new(importer: ImporterVehicleStores.new(current_customer), replace: params[:replace], json: params[:stores])
      else
        ImportCsv.new(importer: ImporterVehicleStores.new(current_customer), replace: params[:replace], file: params[:file])
      end

      if import && import.valid? && (stores = import.import(true))
        present stores, with: V01::Entities::Store
      else
        error!({error: import.errors.full_messages}, 422)
      end
    end
  end

end
