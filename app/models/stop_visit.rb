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
class StopVisit < Stop
  delegate :lat,
           :lng,
           :time_window_start_1, :time_window_start_1_time, :time_window_start_1_absolute_time,
           :time_window_end_1, :time_window_end_1_time, :time_window_end_1_absolute_time,
           :time_window_start_2, :time_window_start_2_time, :time_window_start_2_absolute_time,
           :time_window_end_2, :time_window_end_2_time, :time_window_end_2_absolute_time,
           :force_position,
           :priority, :priority_text,
           :name,
           :street,
           :postalcode,
           :city,
           :state,
           :country,
           :detail,
           :comment,
           :phone_number,
           :color,
           :icon,
           :icon_size,
           :default_icon,
           :default_icon_size,
           to: :visit

  validates :visit, presence: true

  def ref
    visit.ref || visit.destination.ref
  end

  def order
    planning = route.planning
    if planning.customer.enable_orders && planning.order_array && planning.date
      planning.order_array.orders.where(visit_id: visit.id, shift: planning.date - planning.order_array.base_date).first
    end
  end

  def position?
    visit.destination.lat.present? && visit.destination.lng.present?
  end

  def position
    visit.destination
  end

  def duration
    visit.duration || visit.customer.visit_duration || 0
  end

  def duration_time_with_seconds
    visit.duration_time_with_seconds || visit.customer.visit_duration_time_with_seconds || 0
  end

  def destination_duration
    visit.destination.duration || visit.customer.destination_duration || 0
  end

  def destination_duration_time_with_seconds
    visit.destination.duration_time_with_seconds || visit.customer.destination_duration_time_with_seconds || 0
  end

  def base_id
    "d#{visit.id}"
  end

  def base_updated_at
    [visit.updated_at, visit.destination.updated_at].max
  end

  def to_s
    "#{active ? 'x' : '_'} #{visit.destination.name}"
  end

  def optim_type
    'service'
  end
end
