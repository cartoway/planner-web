# Copyright © Mapotempo, 2017
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

class SopacService < DeviceService

  def vehicles_temperature(customer)
    return unless sopac_active?(customer)

    with_cache [:vehicles_temperature, service_name, customer.id] do
      service.vehicles_temperature customer
    end
  end

  def list_devices
    return [] unless sopac_active?(customer)

    # Registry is filled by the broker consumer; do not cache empty lists (stale select options).
    service.list_devices customer
  end

  def vehicle_pos
    return [] unless sopac_active?(customer)

    with_cache [:vehicle_pos, service_name, customer.id] do
      service.vehicle_pos customer
    end
  end

  private

  def sopac_active?(customer)
    SopacBroker::BrokerConfig.customer_enabled?(customer)
  end
end
