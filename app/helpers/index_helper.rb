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
  def customer_summary
    return {} unless @customer

    # Route default_scope already includes route_data / start_ / stop_; preload routes+tags once for the 5 cards.
    latest_plannings = @customer.plannings
                                .reorder('date DESC NULLS LAST, updated_at DESC')
                                .includes(:tags, :routes)
                                .first(5)
    latest_vehicle_usage_set = @customer.vehicle_usage_sets.reorder(updated_at: :desc).first

    {
      plannings: {
        count: @customer.plannings_count,
        latest: latest_plannings,
        limit: @customer.default_max_plannings
      },
      zonings: {
        count: @customer.zonings.count,
        latest: @customer.zonings.reorder(updated_at: :desc).first(5),
        limit: @customer.default_max_zonings
      },
      destinations: {
        count: @customer.destinations_count,
        latest: @customer.destinations.reorder(updated_at: :desc).first(5),
        limit: @customer.default_max_destinations
      },
      stores: {
        count: @customer.stores.count,
        latest: @customer.stores.reorder(updated_at: :desc).first(5)
      },
      vehicles: {
        count: @customer.vehicles_count,
        latest: @customer.vehicles.reorder(updated_at: :desc).first(5)
      },
      vehicle_usages: {
        count: latest_vehicle_usage_set ? latest_vehicle_usage_set.vehicle_usages.count : 0,
        latest: latest_vehicle_usage_set ? latest_vehicle_usage_set.vehicle_usages.reorder(updated_at: :desc).first(5) : []
      },
      vehicle_usage_sets: {
        count: @customer.vehicle_usage_sets.count,
        latest: @customer.vehicle_usage_sets.reorder(updated_at: :desc).first(5),
        limit: @customer.default_max_vehicle_usage_sets
      },
      statistics: {
        exists: @customer.reseller.customer_dashboard_url.present?,
        url: @customer.reseller.customer_dashboard_url&.gsub('{LG}', I18n.locale.to_s)&.gsub('{ID}', @customer.id.to_s)
      },
      extra_statistics: {
        exists: @customer.reseller.extra_dashboard_url.present?,
        url: @customer.reseller.extra_dashboard_url&.gsub('{LG}', I18n.locale.to_s)&.gsub('{ID}', @customer.id.to_s)
      }
    }
  end
end
