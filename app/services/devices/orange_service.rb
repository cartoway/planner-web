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
class OrangeService < DeviceService
  def list_devices(params = {})
    if (customer.devices[service_name] && customer.devices[:orange][:username]) || (params && params[:username])
      with_cache [:list_devices, service_name, customer.id, customer.devices[:orange][:username]] do
        service.list_devices customer, params
      end
    else
      []
    end
  end

  def vehicle_pos
    if customer.devices[service_name] && customer.devices[:orange][:username]
      with_cache [:vehicle_pos, service_name, customer.id, customer.devices[:orange][:username]] do
        service.vehicle_pos customer
      end
    end
  end
end
