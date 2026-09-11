# Copyright © Mapotempo, 2013-2014
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
module VehiclesHelper
  def current_router_options(vehicle)
    router_options = {}
    (vehicle.customer.router.options.merge(vehicle.router.try(:options) || {})).each do |key, value|
      router_options[key.to_s] = vehicle.router_options[key.to_s] || vehicle.customer.router_options[key.to_s]
    end
    return router_options
  end

  def customer_router_boolean_default_label(customer, key)
    value = customer.router_options[key.to_s]
    yes = if key.to_s == 'traffic'
            ValueToBoolean.value_to_boolean(value)
          else
            ValueToBoolean.value_to_boolean(value, true)
          end
    yes ? t("customers.form.router_options_#{key}_yes") : t("customers.form.router_options_#{key}_no")
  end
end
