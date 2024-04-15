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
class VehicleUsageSet < ApplicationRecord
  default_scope { order(:id) }

  belongs_to :customer, inverse_of: :vehicle_usage_sets
  belongs_to :store_start, class_name: 'Store', inverse_of: :vehicle_usage_set_starts
  belongs_to :store_stop, class_name: 'Store', inverse_of: :vehicle_usage_set_stops
  belongs_to :store_rest, class_name: 'Store', inverse_of: :vehicle_usage_set_rests
  has_many :plannings, inverse_of: :vehicle_usage_set
  before_destroy :destroy_vehicle_usage_set # Update planning.vehicle_usage_set before destroy self
  has_many :vehicle_usages, inverse_of: :vehicle_usage_set, dependent: :delete_all, autosave: true

  nilify_blanks

  auto_strip_attributes :name

  include TimeAttr
  attribute :time_window_start, ScheduleType.new
  attribute :time_window_end, ScheduleType.new
  attribute :rest_start, ScheduleType.new
  attribute :rest_stop, ScheduleType.new
  attribute :rest_duration, ScheduleType.new
  attribute :service_time_start, ScheduleType.new
  attribute :service_time_end, ScheduleType.new
  attribute :work_time, ScheduleType.new
  attribute :max_ride_duration, ScheduleType.new
  time_attr :time_window_start, :time_window_end, :rest_start, :rest_stop, :rest_duration, :service_time_start, :service_time_end, :work_time, :max_ride_duration

  validates :customer, presence: true
  validates :name, presence: true

  validates :time_window_start, presence: true
  validates :time_window_end, presence: true
  validate :time_window_end_after_end
  validate :rest_stop_after_rest_start
  validate :work_time_inside_window
  validates :rest_start, presence: {if: :rest_duration?, message: ->(*_) { I18n.t('activerecord.errors.models.vehicle_usage_set.missing_rest_window') }}
  validates :rest_stop, presence: {if: :rest_duration?, message: ->(*_) { I18n.t('activerecord.errors.models.vehicle_usage_set.missing_rest_window') }}
  validates :rest_duration, presence: {if: :rest_start?, message: ->(*_) { I18n.t('activerecord.errors.models.vehicle_usage_set.missing_rest_duration') }}
  validates :max_distance, numericality: true, allow_nil: true
  validates :max_ride_distance, numericality: true, allow_nil: true

  after_initialize :assign_defaults, if: :new_record?
  before_create :check_max_vehicle_usage_set
  before_update :update_outdated

  amoeba do
    exclude_association :plannings

    customize(lambda { |_original, copy|
      def copy.assign_defaults; end

      def copy.update_outdated; end

      copy.vehicle_usages.each{ |vehicle_usage|
        vehicle_usage.vehicle_usage_set = copy
      }
    })
  end

  def duplicate
    copy = self.amoeba_dup
    copy.name += " (#{I18n.l(Time.zone.now, format: :long)})"
    copy
  end

  private

  def create_vehicle_usages
    if customer
      customer.vehicles.each { |vehicle|
        # if vehicle is not yet saved, vehicle_usage will be created in vehicle callback
        if vehicle.id
          vehicle_usages.build(vehicle: vehicle)
        end
      }
    end
  end

  def assign_defaults
    self.time_window_start ||= 8 * 3600 unless time_window_start
    self.time_window_end ||= 18 * 3600 unless time_window_end
    create_vehicle_usages
  end

  def check_max_vehicle_usage_set
    !self.customer.too_many_vehicle_usage_sets? || raise(Exceptions::OverMaxLimitError.new(I18n.t('activerecord.errors.models.customer.attributes.vehicle_usage_sets.over_max_limit')))
  end

  def update_outdated
    if rest_duration_changed?
      vehicle_usages.each(&:update_rest)
    end

    if time_window_start_changed? || time_window_end_changed? || store_start_id_changed? || store_stop_id_changed? || rest_start_changed? || rest_stop_changed? || rest_duration_changed? || store_rest_id_changed? || service_time_start_changed? || service_time_end_changed? || work_time_changed? || max_distance || max_ride_distance_changed? || max_ride_duration_changed?
      vehicle_usages.each{ |vehicle_usage|
        if (time_window_start_changed? && vehicle_usage.default_time_window_start == time_window_start) ||
          (time_window_end_changed? && vehicle_usage.default_time_window_end == time_window_end) ||

          (store_start_id_changed? && vehicle_usage.default_store_start == store_start) ||
          (store_stop_id_changed? && vehicle_usage.default_store_stop == store_stop) ||

          (work_time_changed? && vehicle_usage.default_work_time == work_time) ||

          (rest_start_changed? && vehicle_usage.default_rest_start == rest_start) ||
          (rest_stop_changed? && vehicle_usage.default_rest_stop == rest_stop) ||

          (rest_duration_changed? && vehicle_usage.default_rest_duration == rest_duration) ||

          (store_rest_id_changed? && vehicle_usage.default_store_rest == store_rest) ||

          (service_time_start_changed? && vehicle_usage.default_service_time_start == service_time_start) ||
          (service_time_end_changed? && vehicle_usage.default_service_time_end == service_time_end) ||

          (max_distance_changed? && vehicle_usage.vehicle.max_distance == max_distance) ||
          (max_ride_distance_changed? && vehicle_usage.vehicle.max_ride_distance == max_ride_distance) ||
          (max_ride_duration_changed? && vehicle_usage.vehicle.max_ride_duration == max_ride_duration)

          vehicle_usage.routes.each{ |route|
            route.outdated = true
          }
        end
      }
    end
  end

  def destroy_vehicle_usage_set
    default = customer.vehicle_usage_sets.find{ |vehicle_usage_set| vehicle_usage_set != self && !vehicle_usage_set.destroyed? }
    if !default
      errors[:base] << I18n.t('activerecord.errors.models.vehicle_usage_set.at_least_one')
      return false
    else
      customer.plannings.select{ |planning| planning.vehicle_usage_set == self }.each{ |planning|
        planning.vehicle_usage_set = default
        planning.save!
      }
    end
  end

  def time_window_end_after_end
    if self.time_window_start.present? && self.time_window_end.present? && self.time_window_end <= self.time_window_start
      errors.add(:time_window_end, I18n.t('activerecord.errors.models.vehicle_usage_set.attributes.time_window_end.after'))
    end
  end

  def rest_stop_after_rest_start
    if self.rest_start.present? && self.rest_stop.present? && self.rest_stop < self.rest_start
      errors.add(:rest_stop, I18n.t('activerecord.errors.models.vehicle_usage_set.attributes.rest_stop.after'))
    end
  end

  def work_time_inside_window
    if self.work_time.present? && self.time_window_start.present? && self.time_window_end.present? && self.work_time > (self.time_window_end - self.time_window_start) - ((self.service_time_start || 0) + (self.service_time_end || 0))
      errors.add(:work_time, I18n.t('activerecord.errors.models.vehicle_usage_set.work_time_inside_window'))
    end
  end
end
