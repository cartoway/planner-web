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
    visit.destination.ref
  end

  def ref_visit
    visit.ref
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

  # Raw visit duration
  def base_duration
    visit.duration || visit.customer.visit_duration || 0
  end

  # Effective visit duration (base × vehicle coef).
  def duration
    apply_duration_coef(base_duration, visit_duration_coef)
  end

  def duration_time_with_seconds
    format_duration_time_with_seconds(duration)
  end

  # Raw destination duration
  def base_destination_duration
    visit.destination.duration || visit.customer.destination_duration || 0
  end

  # Effective destination duration (base × vehicle coef).
  def destination_duration
    apply_duration_coef(base_destination_duration, destination_duration_coef)
  end

  def destination_duration_time_with_seconds
    format_duration_time_with_seconds(destination_duration)
  end

  def visit_duration_coef
    route&.vehicle_usage&.default_visit_duration_coef || 1
  end

  def destination_duration_coef
    route&.vehicle_usage&.default_destination_duration_coef || 1
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

  private

  def apply_duration_coef(seconds, coef)
    return seconds if seconds.zero? || coef.nil? || coef == 1

    (seconds * coef).round
  end

  def format_duration_time_with_seconds(seconds)
    return 0 if seconds.zero?

    Time.at(seconds).utc.strftime('%H:%M:%S')
  end
end
