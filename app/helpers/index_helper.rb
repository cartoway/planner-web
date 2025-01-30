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
module IndexHelper
  def kpis
    return {} unless @customer

    {
      plannings: {
        total: @customer.plannings.count,
        last: @customer.plannings.reorder(updated_at: :desc).first(5)
      },
      zonings: {
        total: @customer.zonings.count,
        last: @customer.zonings.reorder(updated_at: :desc).first(5)
      },
      destinations: {
        total: @customer.destinations.count,
        last: @customer.destinations.reorder(updated_at: :desc).first(5)
      },
      stores: {
        total: @customer.stores.count,
        last: @customer.stores.reorder(updated_at: :desc).first(5)
      },
      vehicles: {
        total: @customer.vehicles.count,
        nb_set: @customer.vehicle_usage_sets.count,
        last: @customer.vehicles.reorder(updated_at: :desc).first(5)
      },
      statistics: {
        exists: @customer.reseller.customer_dashboard_url.present?,
        url: @customer.reseller.customer_dashboard_url&.gsub('{LG}', I18n.locale.to_s)&.gsub('{ID}', @customer.id.to_s)
      }
    }
  end
end
