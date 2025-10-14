# Copyright © Mapotempo, 2015
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
class StopRest < Stop
  def position?
    !route.vehicle_usage.default_store_rest.nil? && !route.vehicle_usage.default_store_rest.lat.nil? && !route.vehicle_usage.default_store_rest.lng.nil?
  end

  def position
    route.vehicle_usage.default_store_rest
  end

  def lat
    if position?
      route.vehicle_usage.default_store_rest.lat
    end
  end

  def lng
    if position?
      route.vehicle_usage.default_store_rest.lng
    end
  end

  def time_window_start_1
    route.vehicle_usage.default_rest_start
  end

  def time_window_start_1_time
    route.vehicle_usage.default_rest_start_time
  end

  def time_window_start_1_absolute_time
    route.vehicle_usage.default_rest_start_absolute_time
  end

  def time_window_end_1
    route.vehicle_usage.default_rest_stop
  end

  def time_window_end_1_time
    route.vehicle_usage.default_rest_stop_time
  end

  def time_window_end_1_absolute_time
    route.vehicle_usage.default_rest_stop_absolute_time
  end

  def time_window_start_2
    nil
  end

  def time_window_start_2_time
    nil
  end

  def time_window_end_2
    nil
  end

  def time_window_end_2_time
    nil
  end

  def priority
    nil
  end

  def force_position
    nil
  end

  def duration
    route.vehicle_usage.default_rest_duration || 0
  end

  def duration_time_with_seconds
    route.vehicle_usage.default_rest_duration_time_with_seconds || 0
  end

  def destination_duration
    0
  end

  def destination_duration_time_with_seconds
    0
  end

  def base_id
    "r#{route.vehicle_usage.id}"
  end

  def base_updated_at
    route.vehicle_usage.updated_at
  end

  def ref
    nil
  end

  def name
    if position?
      route.vehicle_usage.default_store_rest.name
    else
      I18n.t('stops.default.name_rest')
    end
  end

  def street
    if position?
      route.vehicle_usage.default_store_rest.street
    end
  end

  def postalcode
    if position?
      route.vehicle_usage.default_store_rest.postalcode
    end
  end

  def city
    if position?
      route.vehicle_usage.default_store_rest.city
    end
  end

  def state
    if route.planning.customer.with_state? && position?
      route.vehicle_usage.default_store_rest.state
    end
  end

  def country
    if position?
      route.vehicle_usage.default_store_rest.country
    end
  end

  def detail
    nil
  end

  def comment
    nil
  end

  def phone_number
    nil
  end

  def color
    route.vehicle_usage.default_store_rest && route.vehicle_usage.default_store_rest.color
  end

  def icon
    route.vehicle_usage.default_store_rest && route.vehicle_usage.default_store_rest.icon
  end

  def icon_size
    route.vehicle_usage.default_store_rest && route.vehicle_usage.default_store_rest.icon_size
  end

  def to_s
    "#{active ? 'x' : '_'} [Rest]"
  end

  def optim_type
    'rest'
  end
end
