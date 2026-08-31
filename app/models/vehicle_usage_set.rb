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

  attr_accessor :import_skip

  belongs_to :customer, inverse_of: :vehicle_usage_sets
  belongs_to :store_start, class_name: 'Store', inverse_of: :vehicle_usage_set_starts, optional: true
  belongs_to :store_stop, class_name: 'Store', inverse_of: :vehicle_usage_set_stops, optional: true
  belongs_to :store_rest, class_name: 'Store', inverse_of: :vehicle_usage_set_rests, optional: true
  has_many :plannings, inverse_of: :vehicle_usage_set
  before_destroy :destroy_vehicle_usage_set # Update planning.vehicle_usage_set before destroy self
  has_many :vehicle_usages, -> { ordered_by_index }, inverse_of: :vehicle_usage_set, dependent: :delete_all, autosave: true

  has_many :store_reload_vehicle_usage_sets, inverse_of: :vehicle_usage_set, dependent: :destroy
  has_many :store_reloads, through: :store_reload_vehicle_usage_sets

  nilify_blanks

  auto_strip_attributes :name

  include LocalizedAttr
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
  attr_localized :cost_distance, :cost_fixed, :cost_time

  validates :customer, presence: true
  validates :name, presence: true
  validates :cost_distance, numericality: {only_float: true, greater_than_or_equal_to: 0}, allow_nil: true
  validates :cost_fixed, numericality: {only_float: true, greater_than_or_equal_to: 0}, allow_nil: true
  validates :cost_time, numericality: {only_float: true, greater_than_or_equal_to: 0}, allow_nil: true
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
  validates :visit_duration_coef, numericality: { greater_than: 0, less_than_or_equal_to: 5 }, if: :visit_duration_coef
  validates :destination_duration_coef, numericality: { greater_than: 0, less_than_or_equal_to: 5 }, if: :destination_duration_coef

  after_initialize :assign_defaults, if: :new_record?
  before_create :check_max_vehicle_usage_set, unless: :import_skip
  before_update :update_outdated

  RELATED_ATTRIBUTES = %i[
    time_window_start time_window_end work_time
    rest_start rest_stop rest_duration
    service_time_start service_time_end
    max_distance max_ride_distance max_ride_duration
    cost_distance cost_fixed cost_time
  ].freeze

  RELATED_OBJECT_ATTRIBUTES = %i[store_start store_stop store_rest].freeze

  RELATED_COEF_ATTRIBUTES = %i[visit_duration_coef destination_duration_coef].freeze

  def default_visit_duration_coef
    visit_duration_coef || 1
  end

  def default_destination_duration_coef
    destination_duration_coef || 1
  end

  def reorder_vehicle_usages!(ordered_ids)
    ordered_ids = Array(ordered_ids).map(&:to_i)
    expected_ids = vehicle_usages.pluck(:id).sort
    raise ArgumentError, 'invalid vehicle usage ids' unless ordered_ids.sort == expected_ids

    VehicleUsage.transaction do
      # Unique index on (vehicle_usage_set_id, index): assign temporary negative indices first.
      assign_vehicle_usage_indices!(ordered_ids) { |position| -(position + 1) }
      assign_vehicle_usage_indices!(ordered_ids, &:itself)
    end
  end

  def duplicate
    vehicle_usage_set_id = self.custom_duplicate
    VehicleUsageSet.find(vehicle_usage_set_id)
  end

  def custom_duplicate
    VehicleUsageSet.transaction do
      attributes = self.import_attributes.except('id')
      attributes['name'] += " (#{I18n.l(Time.zone.now, format: :long)})"
      vehicle_usage_set_id = VehicleUsageSet.import([attributes], validate: false).ids.first
      new_vehicle_usage_attributes = self.vehicle_usages.map.with_index { |vehicle_usage, position|
        vehicle_usage.import_attributes.except('id').merge(
          'vehicle_usage_set_id' => vehicle_usage_set_id,
          'index' => position
        )
      }
      VehicleUsage.import(new_vehicle_usage_attributes, validate: false)
      vehicle_usage_set_id
    end
  end

  private

  def assign_vehicle_usage_indices!(ordered_ids)
    ordered_ids.each_with_index do |vehicle_usage_id, position|
      vehicle_usages.where(id: vehicle_usage_id).update_all(index: yield(position))
    end
  end

  def vehicle_uses_set_value?(vehicle_usage, attribute)
    vehicle_usage.public_send("default_#{attribute}") == public_send(attribute)
  end

  def related_attribute_changed?
    RELATED_ATTRIBUTES.any? { |attribute| public_send("#{attribute}_changed?") } ||
      RELATED_OBJECT_ATTRIBUTES.any? { |attribute| public_send("#{attribute}_id_changed?") } ||
      RELATED_COEF_ATTRIBUTES.any? { |attribute| public_send("#{attribute}_changed?") }
  end

  def routes_need_recompute?(vehicle_usage)
    RELATED_ATTRIBUTES.any? { |attribute|
      public_send("#{attribute}_changed?") && vehicle_uses_set_value?(vehicle_usage, attribute)
    } || RELATED_OBJECT_ATTRIBUTES.any? { |attribute|
      public_send("#{attribute}_id_changed?") && vehicle_uses_set_value?(vehicle_usage, attribute)
    } || RELATED_COEF_ATTRIBUTES.any? { |attribute|
      public_send("#{attribute}_changed?") && vehicle_usage.public_send(attribute).nil?
    }
  end

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
    return if import_skip

    if rest_duration_changed?
      vehicle_usages.each(&:update_rest)
    end

    if related_attribute_changed?
      vehicle_usages.each { |vehicle_usage|
        next unless routes_need_recompute?(vehicle_usage)

        vehicle_usage.routes.each { |route|
          route.outdated = true
        }
      }
    end
  end

  def destroy_vehicle_usage_set
    default = customer.vehicle_usage_sets.find{ |vehicle_usage_set| vehicle_usage_set != self && !vehicle_usage_set.destroyed? }
    if !default
      errors.add(:base, I18n.t('activerecord.errors.models.vehicle_usage_set.at_least_one'))
      throw :abort
    else
      Route.no_touching do
        customer.plannings.select{ |planning| planning.vehicle_usage_set == self }.each{ |planning|
          planning.vehicle_usage_set = default
          planning.save!
        }
      end
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
