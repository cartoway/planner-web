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
require "#{Rails.root}/lib/stop_quantities"

module StopsHelper
  def stop_quantities(stop, vehicle, options = {})
    StopQuantities.normalize(stop, vehicle, options)
  end

  def stop_order_quantities(stop)
    stop.order.products.map(&:code).each_with_object({}){ |code, hash| hash.key?(code) ? hash[code] += 1 : hash[code] = 1 }
  end

  def stop_condensed_time_windows(stop)
    return if !stop.time_window_start_1 && !stop.time_window_end_1

    condensed_string = ""
    if stop.time_window_start_1_time
      day_number_start_1 = number_of_days(stop.time_window_start_1)
      condensed_string += stop.time_window_start_1_time
      condensed_string += "(+#{day_number_start_1})" if day_number_start_1
      condensed_string += " (#{I18n.t('plannings.edit.popup.time_window_start_1')})" unless stop.time_window_end_1_time
    end
    condensed_string += '-' if stop.time_window_start_1_time && stop.time_window_end_1_time
    if stop.time_window_end_1_time
      day_number_end_1 = number_of_days(stop.time_window_end_1)
      condensed_string += stop.time_window_end_1_time
      condensed_string += "(+#{day_number_end_1})" if day_number_end_1
      condensed_string += " (#{I18n.t('plannings.edit.popup.time_window_end_1')})" unless stop.time_window_start_1_time
    end
    return condensed_string if !stop.time_window_start_2 && !stop.time_window_end_2

    condensed_string += ' / '
    if stop.time_window_start_2_time
      day_number_start_2 = number_of_days(stop.time_window_start_2)
      condensed_string += stop.time_window_start_2_time
      condensed_string += "(+#{day_number_start_2})" if day_number_start_2
      condensed_string += " (#{I18n.t('plannings.edit.popup.time_window_start_2')})" unless stop.time_window_end_2_time
    end
    condensed_string += '-' if stop.time_window_start_2_time && stop.time_window_end_2_time
    if stop.time_window_end_2_time
      day_number_end_2 = number_of_days(stop.time_window_end_2)
      condensed_string += stop.time_window_end_2_time
      condensed_string += "(+#{day_number_end_2})" if day_number_end_2
      condensed_string += " (#{I18n.t('plannings.edit.popup.time_window_end_2')})" unless stop.time_window_start_2_time
    end
    condensed_string
  end
end
