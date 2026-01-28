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

  after_initialize :assign_defaults, if: -> { new_record? }
  after_initialize :ensure_route_data, if: -> { route_data_id.nil? }

  validates :store_reload, presence: true
  validates :route_data_id, presence: true

  # A StopStore is always active
  def active=(_value)
    write_attribute(:active, true)
  end

  def ref
    store_reload.store.ref
  end

  def ref_visit
    store_reload.ref
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

  def assign_defaults
    self.route_data = RouteData.create! if self.route_data_id.nil?
  end

  def ensure_route_data
    if route_data_id.nil? && route_id.present?
      self.route_data = RouteData.create!
    end
  end
end
