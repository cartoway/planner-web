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

class StoreReload < ApplicationRecord
  default_scope { order(:id) }

  belongs_to :store, inverse_of: :store_reloads
  has_many :stop_stores, inverse_of: :store_reload

  has_many :store_reload_vehicle_usages, inverse_of: :store_reload, dependent: :destroy
  has_many :vehicle_usages, through: :store_reload_vehicle_usages

  has_many :store_reload_vehicle_usage_sets, inverse_of: :store_reload, dependent: :destroy
  has_many :vehicle_usage_sets, through: :store_reload_vehicle_usage_sets

  delegate :customer, :lat, :lng, :name, :street, :postalcode, :city, :state, :country, :color, :icon, :icon_size, :default_icon, :default_icon_size, to: :store

  nilify_blanks
  validates :store, presence: true
  validates :ref, uniqueness: { scope: :store_id, case_sensitive: true }, allow_nil: true, allow_blank: true

  include TimeAttr
  attribute :time_window_start, ScheduleType.new
  attribute :time_window_end, ScheduleType.new
  time_attr :time_window_start, :time_window_end
  attribute :duration, ScheduleType.new
  time_attr :duration

  validate :time_window_end_after_time_window_start

  include Consistency
  validate_consistency([]) { |store_reload| store_reload.store.try :customer_id }

  before_update :update_outdated

  include RefSanitizer

  amoeba do
    exclude_association :stop_stores

    customize(lambda { |_original, copy|
      def copy.update_outdated; end
    })
  end

  def outdated
    begin
      ActiveRecord::Base.lock_optimistically = false
      stop_stores.each { |stop|
        if !stop.route.outdated
          stop.route.outdated = true
          stop.route.save!
        end
      }
    ensure
      ActiveRecord::Base.lock_optimistically = true
    end
  end

  def position?
    store.lat.present? && store.lng.present?
  end

  def position
    store
  end

  def default_duration
    duration || store.customer.visit_duration
  end

  def default_duration_time_with_seconds
    duration_time_with_seconds || store.customer.visit_duration_time_with_seconds
  end

  def base_id
    "sr#{id}"
  end

  def base_updated_at
    [updated_at, store.updated_at].max
  end

  def to_s
    [store.name, ref].compact.join(' ')
  end

  private

  def update_outdated
    if time_window_start_changed? || time_window_end_changed? || duration_changed?
      outdated
    end
  end

  def time_window_end_after_time_window_start
    if self.time_window_start.present? && self.time_window_end.present? && self.time_window_end < self.time_window_start
      raise Exceptions::CloseAndOpenErrors.new(nil, id, nested_attr: :time_window_end, record: self)
    end
  rescue Exceptions::CloseAndOpenErrors
    self.errors.add(:time_window_end, :after, s: I18n.t('activerecord.attributes.store_reload.time_window_start').downcase)
  end
end
