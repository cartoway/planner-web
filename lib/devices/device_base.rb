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
class DeviceBase
  attr_accessor :api_url, :api_key, :admin_api_key

  def planning_date(planning)
    planning.date ? planning.date.beginning_of_day : Time.zone.now.beginning_of_day
  end

  def p_time(route, time)
    planning_date(route.planning) + time
  end

  def number_of_days(time_in_seconds)
    if time_in_seconds && time_in_seconds > 0
      number_of_days = (time_in_seconds / 86400).to_i
      number_of_days > 0 ? " (+#{number_of_days.to_s})" : ''
    else
      ''
    end
  end

  def encode_uid(description, order_id, date = Time.now)
    # If order_id is a Visit or Rest, keep stop_type in encoded order_id
    if order_id.is_a? String
      stop_type = order_id[0]
      order_id = order_id[1..-1].to_i
    end
    unique_base_order_id = date.to_i.to_s(36) + ":#{stop_type}" + order_id.to_s(36)
    description.upcase.gsub(/[^A-Z0-9\s]/i, '')[0..(19 - unique_base_order_id.length)] + unique_base_order_id # max length for tomtom
  end

  # Return a string, prefixed with 'v' (Visit), 'r' (Rest), or nothing (Store)
  def decode_uid(order_id)
    suffix = order_id.split(':').last
    if suffix[0] == 'v' || suffix[0] == 'r'
      suffix[0] + suffix[1..-1].to_i(36).to_s
    else
      suffix.to_i(36).to_s
    end
  end

  class << self
    def is_a_store?(order_id)
      order_id.to_i != 0
    end
  end
end

class DeviceServiceError < StandardError
end
