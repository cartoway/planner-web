# Copyright © Mapotempo, 2013-2015
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

class Vehicle < ApplicationRecord
  default_scope { order(:id) }

  belongs_to :customer
  belongs_to :router
  has_many :vehicle_usages, inverse_of: :vehicle, dependent: :destroy, autosave: true
  has_many :zones, inverse_of: :vehicle, dependent: :nullify, autosave: true

  has_and_belongs_to_many :tags, autosave: true, after_add: :update_tags_track, after_remove: :update_tags_track

  enum router_dimension: Router::DIMENSION
  serialize :capacities, DeliverableUnitQuantity

  include HashBoolAttr
  store_accessor :router_options, :time, :distance, :avoid_zones, :isochrone, :isodistance, :traffic, :track, :motorway, :toll, :low_emission_zone, :trailers, :weight, :weight_per_axle, :height, :width, :length, :hazardous_goods, :max_walk_distance, :approach, :snap, :strict_restriction
  hash_bool_attr :router_options, :time, :distance, :avoid_zones, :isochrone, :isodistance, :traffic, :track, :motorway, :toll, :low_emission_zone, :strict_restriction

  include TimeAttr
  attribute :max_ride_duration, ScheduleType.new
  time_attr :max_ride_duration

  nilify_blanks
  auto_strip_attributes :name
  validates :customer, presence: true
  validates :name, presence: true
  validates :emission, numericality: {only_float: true}, allow_nil: true
  validates :consumption, numericality: {only_float: true}, allow_nil: true
  validates :color, presence: true
  validates_format_of :color, with: /\A(\#[A-Fa-f0-9]{6})\Z/
  validates :speed_multiplier, numericality: { greater_than_or_equal_to: 0.5, less_than_or_equal_to: 1.5 }, if: :speed_multiplier
  validates :contact_email, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i }, allow_blank: true
  validate :capacities_validator
  validates :max_distance, numericality: true, allow_nil: true
  validates :max_ride_distance, numericality: true, allow_nil: true

  after_initialize :assign_defaults, :increment_max_vehicles, if: 'new_record?'
  before_validation :check_router_options_format
  before_create :create_vehicle_usage
  before_save :nilify_router_options_blanks
  before_update :update_outdated, :update_color

  include Consistency
  validate_consistency :tags

  after_save -> { @tag_ids_changed = false }

  before_destroy :destroy_vehicle

  include RefSanitizer

  include LocalizedAttr

  attr_localized :emission, :consumption, :capacities

  scope :for_reseller_id, ->(reseller_id) { joins(:customer).where(customers: {reseller_id: reseller_id}) }

  include TypedAttribute
  typed_attr :custom_attributes

  def capacities_validator
    !capacities || capacities.values.each do |q|
      raise Exceptions::NegativeErrors.new(q, id) if Float(q) < 0 # Raise both Float && NegativeErrors type
    end
  rescue StandardError => e
    errors.add :capacities, :not_float if e.is_a?(ArgumentError) || e.is_a?(TypeError)
    errors.add :capacities, :negative_value, {value: e.object[:value]} if e.is_a? Exceptions::NegativeErrors
  end

  def self.emissions_table
    [
      [I18n.t('vehicles.emissions_nothing', n: 0), '0.0'],
      [I18n.t('vehicles.emissions_light_petrol', n: self.localize_numeric_value(2.71)), '2.71'],
      [I18n.t('vehicles.emissions_light_diesel', n: self.localize_numeric_value(3.07)), '3.07'],
      [I18n.t('vehicles.emissions_light_lgp', n: self.localize_numeric_value(1.77)), '1.77'],
      [I18n.t('vehicles.emissions_ngv', n: self.localize_numeric_value(2.13)), '2.13'],
    ]
  end

  amoeba do
    exclude_association :vehicle_usages
    exclude_association :zones

    customize(lambda { |_original, copy|
      def copy.assign_defaults; end

      def copy.increment_max_vehicles; end

      def copy.create_vehicle_usage; end

      def copy.update_outdated; end

      def copy.destroy_vehicle; end
    })
  end

  def devices
    if self[:devices].respond_to?('deep_symbolize_keys!')
      self[:devices].deep_symbolize_keys!
    else
      self[:devices]
    end
  end

  # Used in form helpers (store_accessor cannot be used since devices keys are symbolized)
  Mapotempo::Application.config.devices.to_h.each{ |_device_name, device_object|
    if device_object.respond_to?('definition')
      device_definition = device_object.definition
      if device_definition.key?(:forms) && device_definition[:forms].key?(:vehicle)
        device_definition[:forms][:vehicle].keys.each{ |key|
          define_method(key) do
            self.devices[key]
          end
        }
      end
    end
  }

  def default_router
    self.router || customer.router
  end

  def default_router_dimension
    self.router_dimension || customer.router_dimension
  end

  def default_router_options
    default_router.options.each do |key, value|
      @current_router_options ||= {}
      @current_router_options[key.to_s] = if router_options[key.to_s].nil?
        customer.router_options[key.to_s]
      else
        router_options[key.to_s]
      end
    end if !@current_router_options

    @current_router_options ||= {}
  end

  def default_speed_multiplier
    customer.speed_multiplier * (speed_multiplier || 1)
  end

  def default_capacities
    @default_capacities ||= Hash[customer.deliverable_units.collect{ |du|
      [du.id, capacities && capacities[du.id] ? capacities[du.id] : du.default_capacity]
    }]
    @default_capacities
  end

  def default_capacities?
    default_capacities && default_capacities.values.any?{ |q| q && q > 0 }
  end

  def capacities?
    capacities && capacities.values.any?{ |q| q }
  end

  def capacities_changed?
    !capacities.empty? ? capacities.any?{ |i, q| q != capacities_was[i] } : !capacities_was.empty?
  end

  def update_tags_track(_tag)
    @tag_ids_changed = true
  end

  # Used by validate_consistency
  def tag_ids_changed?
    @tag_ids_changed
  end

  def changed?
    tag_ids_changed? || super
  end

  private

  def assign_defaults
    self.color ||= COLORS_TABLE[0]
  end

  def increment_max_vehicles
    customer.max_vehicles += 1
  end

  def create_vehicle_usage
    h = {}
    customer.vehicle_usage_sets.each{ |vehicle_usage_set|
      u = vehicle_usage_set.vehicle_usages.build(vehicle: self)
      h[vehicle_usage_set] = u
      vehicle_usages << u
    }
    customer.plannings.each{ |planning|
      planning.vehicle_usage_add(h[planning.vehicle_usage_set])
    }
  end

  def nilify_router_options_blanks
    true_options = default_router.options.select { |_, v| v == true }.keys
    write_attribute :router_options, self.router_options.delete_if { |k, v| v.to_s.empty? || true_options.exclude?(k) }
  end

  def update_outdated
    if emission_changed? || consumption_changed? || capacities_changed? || router_id_changed? || router_dimension_changed? || router_options_changed? || speed_multiplier_changed? || max_distance_changed? || max_ride_distance_changed? || max_ride_duration_changed?
      vehicle_usages.each{ |vehicle_usage|
        vehicle_usage.routes.each{ |route|
          route.outdated = true
        }
      }
    end
  end

  def update_color
    if color_changed?
      vehicle_usages.each{ |vehicle_usage|
        vehicle_usage.routes.each{ |route|
          route.vehicle_color_changed = true
        }
      }
    end
  end

  def destroy_vehicle
    default = customer.vehicles.find{ |vehicle| vehicle != self && !vehicle.destroyed? }
    unless default
      errors[:base] << I18n.t('activerecord.errors.models.vehicles.at_least_one')
      false
    end
  end

  def check_router_options_format
    self.router_options.each do |k, v|
      if k == 'distance' || k == 'weight' || k == 'weight_per_axle' || k == 'height' || k == 'width' || k == 'length' || k == 'max_walk_distance'
        self.router_options[k] = Vehicle.to_delocalized_decimal(v) if v.is_a?(String)
      end
    end
  end
end
