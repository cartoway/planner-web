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
class DeviceService
  attr_reader :customer, :service_name, :cache_object, :service, :name

  def initialize(params)
    @customer = params[:customer]
    @cache_object = Planner::Application.config.devices.cache_object
    @name = self.class.name.gsub('Service', '')
    @service_name = @name.underscore.to_sym
    @service = Planner::Application.config.devices[service_name]
  end

  def send_route(route, options = {})
    service.send_route customer, route, options
    route.set_send_to(@service.definition[:label_small]) # TODO: set_send_to already performed in devices_api.rb
    route.last_sent_at
  end

  def clear_route(route)
    service.clear_route customer, route
    route.clear_sent_to
  end

  def service_name_id
    service_name_id = service.definition[:forms][:vehicle] if service.definition[:forms]
    service_name_id.keys.first if service_name_id
  end

  def fetch_stops_status(planning)
    # Key for cache is composed of :updated_at routes because planning will do operations by itself that can invalidate the data for 120 seconds
    key = [:fetch_stops, service_name, planning.customer.id, planning.id, planning.routes.select(&:vehicle_usage?).map(&:updated_at)]
    with_cache(key) do
      planning.fetch_stops_status
    end
  end

  private

  def with_cache(key, &block)
    result = cache_object.read key
    return result if result

    result = yield
    cache_object.write key, result
    result
  end

  def store_cache(cache_key, vehicle_key, data)
    stored_data = cache_object.read(cache_key) || []
    data_index = stored_data.index{ |s_data| s_data[vehicle_key] == data[vehicle_key] }
    if data_index
      stored_data[data_index] = data
    else
      stored_data.push(data)
    end
    cache_object.write cache_key, stored_data
    stored_data
  end
end
