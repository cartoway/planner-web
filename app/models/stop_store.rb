# Copyright © Cartoway, 2025
#
# This file is part of Cartoway Planner.
#
# Cartoway Planner is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Cartoway Planner is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Cartoway Planner. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#

class StopStore < Stop
  delegate :lat,
           :lng,
           :name,
           :street,
           :postalcode,
           :city,
           :state,
           :country,
           :color,
           :icon,
           :icon_size,
           :default_icon,
           :default_icon_size,
           :time_window_start, :time_window_start_time, :time_window_start_absolute_time,
           :time_window_end, :time_window_end_time, :time_window_end_absolute_time,
           :max_reload,
           to: :store_reload

  validates :store_reload, presence: true

  before_create :validate_max_reload_per_route

  def ref
    store_reload.ref || store_reload.store.ref
  end

  def position?
    store_reload.store.lat.present? && store_reload.store.lng.present?
  end

  def position
    store_reload.store
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

  def duration
    store_reload.default_duration || 0
  end

  def duration_time_with_seconds
    store_reload.default_duration_time_with_seconds
  end

  def destination_duration
    0 # TODO: Add store service duration
  end

  def destination_duration_time_with_seconds
    0 # TODO: Add store service duration
  end

  def base_id
    "sr#{store_reload.id}"
  end

  def base_updated_at
    [store_reload.updated_at, store_reload.store.updated_at].max
  end

  def priority
    nil
  end

  def force_position
    nil
  end

  def to_s
    "#{active ? 'x' : '_'} #{[store_reload.store.name, store_reload.ref].compact.join(' ')}"
  end

  def time_window_start_1
    store_reload.time_window_start
  end

  def time_window_start_1_time
    store_reload.time_window_start_time
  end

  def time_window_start_1_absolute_time
    store_reload.time_window_start_absolute_time
  end

  def time_window_end_1
    store_reload.time_window_end
  end

  def time_window_end_1_time
    store_reload.time_window_end_time
  end

  def time_window_end_1_absolute_time
    store_reload.time_window_end_absolute_time
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

  def optim_type
    'reload_depot'
  end

  private

  def validate_max_reload_per_route
    current_count = route.stops.where(type: self.class.name).where.not(id: id).count
    if (current_count + 1) > route.vehicle_usage.default_max_reload.to_i
      errors.add(:base, I18n.t('activerecord.errors.models.stop_store.max_reload_exceeded'))
      throw :abort
    end
  end
end
