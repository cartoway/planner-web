# Copyright © Mapotempo, 2013-2016
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
require 'sanitize'
require 'json'

class Customer < ApplicationRecord
  PRINT_BARCODE = %w(code128).freeze

  default_scope { order(:id) }

  belongs_to :reseller
  belongs_to :profile
  belongs_to :router
  belongs_to :job_destination_geocoding, class_name: 'Delayed::Backend::ActiveRecord::Job', dependent: :destroy, optional: true
  belongs_to :job_store_geocoding, class_name: 'Delayed::Backend::ActiveRecord::Job', dependent: :destroy, optional: true
  belongs_to :job_optimizer, class_name: 'Delayed::Backend::ActiveRecord::Job', dependent: :destroy, optional: true
  has_many :products, inverse_of: :customer, autosave: true, dependent: :delete_all
  has_many :plannings, inverse_of: :customer, autosave: true, dependent: :delete_all
  has_many :order_arrays, inverse_of: :customer, autosave: true, dependent: :delete_all
  has_many :zonings, inverse_of: :customer, dependent: :delete_all
  before_destroy :destroy_disable_vehicle_usage_sets_validation # Declare and run before has_many :vehicle_usage_sets
  has_many :vehicle_usage_sets, inverse_of: :customer, autosave: true, dependent: :destroy
  has_many :vehicles, inverse_of: :customer, autosave: true, dependent: :delete_all
  has_many :stores, inverse_of: :customer, autosave: true, dependent: :delete_all
  has_many :destinations, inverse_of: :customer, autosave: true, dependent: :delete_all
  has_many :visits, through: :destinations
  has_many :tags, inverse_of: :customer, autosave: true, dependent: :delete_all
  has_many :users, inverse_of: :customer, dependent: :destroy
  has_many :deliverable_units, inverse_of: :customer, autosave: true, dependent: :delete_all, after_add: :update_deliverable_units_track, after_remove: :update_deliverable_units_track
  has_many :custom_attributes, inverse_of: :customer, autosave: true, dependent: :delete_all
  has_many :stops_relations, inverse_of: :customer, autosave: true, dependent: :delete_all
  has_many :messaging_logs, dependent: :destroy
  enum router_dimension: Router::DIMENSION

  attr_accessor :deliverable_units_updated, :device, :exclude_users, :migration_skip

  include HashBoolAttr
  store_accessor :router_options, :time, :distance, :avoid_zones, :isochrone, :isodistance, :traffic, :track, :motorway, :toll, :low_emission_zone, :trailers, :weight, :weight_per_axle, :height, :width, :length, :hazardous_goods, :max_walk_distance, :approach, :snap, :strict_restriction
  hash_bool_attr :router_options, :time, :distance, :avoid_zones, :isochrone, :isodistance, :traffic, :track, :motorway, :toll, :low_emission_zone, :strict_restriction
  store_accessor :advanced_options, :import

  include LocalizedAttr # To use to_delocalized_decimal method

  nilify_blanks
  auto_strip_attributes :name, :print_header, :default_country, :print_barcode, :sms_template

  include TimeAttr
  attribute :visit_duration, ScheduleType.new
  attribute :destination_duration, ScheduleType.new
  attribute :stop_max_upper_bound, ScheduleType.new
  attribute :vehicle_max_upper_bound, ScheduleType.new
  time_attr :visit_duration, :destination_duration, :stop_max_upper_bound, :vehicle_max_upper_bound

  attr_reader :layer_id # used for importation

  validates :profile, presence: true
  validates :router, presence: true
  validates :router_dimension, presence: true
  validates :name, presence: true, length: { maximum: 255 }
  validates :default_country, presence: true
  # TODO default_max_destinations
  validates :stores, length: { maximum: Planner::Application.config.max_destinations / 10, message: :over_max_limit }
  validate :validate_plannings_count
  validate :validate_zonings_count
  validate :validate_destinations_count
  validate :validate_vehicle_usage_sets_count
  validates :optimization_cluster_size, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :optimization_vehicle_soft_upper_bound, numericality: { greater_than: 0 }, allow_nil: true
  validates :optimization_stop_soft_upper_bound, numericality: { greater_than: 0 }, allow_nil: true

  validates :max_vehicles, numericality: { greater_than: 0 }
  validate do
    errors.add(:max_vehicles, :not_an_integer) if @invalid_max_vehicle
    !@invalid_max_vehicle
  end
  validates :max_plannings, numericality: { greater_than: 0, less_than_or_equal_to: Planner::Application.config.max_plannings }, allow_nil: true
  validates :max_zonings, numericality: { greater_than: 0, less_than_or_equal_to: Planner::Application.config.max_zonings }, allow_nil: true
  validates :max_destinations, numericality: { greater_than: 0, less_than_or_equal_to: Planner::Application.config.max_destinations }, allow_nil: true
  validates :max_vehicle_usage_sets, numericality: { greater_than: 0, less_than_or_equal_to: Planner::Application.config.max_vehicle_usage_sets }, allow_nil: true
  validates :speed_multiplier, numericality: { greater_than_or_equal_to: 0.5, less_than_or_equal_to: 1.5 }, if: :speed_multiplier
  validates :optimization_minimal_time, numericality: true, allow_nil: true
  validates :optimization_time, numericality: true, allow_nil: true
  validate :validate_optimization_times
  validate :router_belong_to_profile, if: :new_record?
  validates_inclusion_of :print_barcode, in: Customer::PRINT_BARCODE, allow_nil: true
  validates :history_cron_hour, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 23 }, allow_nil: true

  after_initialize :assign_defaults, :update_max_vehicles, if: :new_record?
  after_initialize :assign_device
  before_validation :check_router_options_format
  before_save :sanitize_print_header, :nilify_router_options_blanks
  before_save :devices_update_vehicles, prepend: true
  after_create :create_default_store, :create_default_vehicle_usage_set, :create_default_deliverable_unit

  before_update :update_max_vehicles
  before_update :update_outdated, unless: :migration_skip

  include RefSanitizer

  scope :includes_deps, -> { includes([:profile, :router, :job_optimizer, :job_destination_geocoding, :job_store_geocoding, :users]) }
  scope :includes_stores, -> { includes(:stores) }

  amoeba do
    nullify :job_destination_geocoding_id
    nullify :job_store_geocoding_id
    nullify :job_optimizer_id
    nullify :ref

    # No duplication of OrderArray
    exclude_association :products
    exclude_association :order_arrays
    exclude_association :ref
    exclude_association :users, if: :exclude_users

    customize(lambda { |original, copy|
      def copy.assign_defaults; end

      def copy.update_max_vehicles; end

      def copy.create_default_store; end

      def copy.create_default_vehicle_usage_set; end

      def copy.create_default_deliverable_unit; end

      def copy.update_outdated; end

      def copy.sanitize_print_header; end

      def copy.devices_update_vehicles; end

      copy.save! validate: Planner::Application.config.validate_during_duplication

      deliverable_unit_ids_map = Hash[original.deliverable_units.map(&:id).zip(copy.deliverable_units)].merge(nil => nil)
      original_vehicles_map = Hash[copy.vehicles.zip(original.vehicles)].merge(nil => nil)
      vehicles_map = Hash[original.vehicles.zip(copy.vehicles)].merge(nil => nil)
      vehicle_usage_sets_map = Hash[original.vehicle_usage_sets.zip(copy.vehicle_usage_sets)].merge(nil => nil)
      vehicle_usages_map = Hash[original.vehicle_usage_sets.collect(&:vehicle_usages).flatten.zip(copy.vehicle_usage_sets.collect(&:vehicle_usages).flatten)].merge(nil => nil)
      stores_map = Hash[original.stores.zip(copy.stores)].merge(nil => nil)
      visits_map = Hash[original.destinations.collect(&:visits).flatten.zip(copy.destinations.collect(&:visits).flatten)].merge(nil => nil)
      tags_map = Hash[original.tags.zip(copy.tags)].merge(nil => nil)
      zonings_map = Hash[original.zonings.zip(copy.zonings)].merge(nil => nil)

      copy.vehicles.each{ |vehicle|
        original_vehicle = original_vehicles_map[vehicle]
        vehicle.capacities = Hash[vehicle.capacities.to_a.map{ |q| deliverable_unit_ids_map[q[0]] && [deliverable_unit_ids_map[q[0]].id, q[1]] }.compact]
        vehicle.tags = original_vehicle.tags.map{ |tag| tags_map[tag] }
        vehicle.force_check_consistency = true
        vehicle.save! validate: Planner::Application.config.validate_during_duplication
      }

      copy.vehicle_usage_sets.each{ |vehicle_usage_set|
        vehicle_usage_set.store_start = stores_map[vehicle_usage_set.store_start]
        vehicle_usage_set.store_stop = stores_map[vehicle_usage_set.store_stop]
        vehicle_usage_set.store_rest = stores_map[vehicle_usage_set.store_rest]

        vehicle_usage_set.vehicle_usages.each{ |vehicle_usage|
          vehicle_usage.vehicle = vehicles_map[vehicle_usage.vehicle]
          vehicle_usage.store_start = stores_map[vehicle_usage.store_start]
          vehicle_usage.store_stop = stores_map[vehicle_usage.store_stop]
          vehicle_usage.store_rest = stores_map[vehicle_usage.store_rest]
          vehicle_usage.tags = vehicle_usage.tags.map{ |tag| tags_map[tag] }
          vehicle_usage.force_check_consistency = true
          vehicle_usage.save! validate: Planner::Application.config.validate_during_duplication
        }
        vehicle_usage_set.save! validate: Planner::Application.config.validate_during_duplication
      }

      copy.destinations.each{ |destination|
        destination.tags = destination.tags.collect{ |tag| tags_map[tag] }

        destination.visits.each{ |visit|
          visit.tags = visit.tags.collect{ |tag| tags_map[tag] }
          visit.quantities = Hash[visit.quantities.to_a.map{ |q| deliverable_unit_ids_map[q[0]] && [deliverable_unit_ids_map[q[0]].id, q[1]] }.compact]
          visit.quantities_operations = Hash[visit.quantities_operations.to_a.map{ |q| deliverable_unit_ids_map[q[0]] && [deliverable_unit_ids_map[q[0]].id, q[1]] }.compact]
          visit.force_check_consistency = true
          visit.save! validate: Planner::Application.config.validate_during_duplication
        }
        destination.force_check_consistency = true
        destination.save! validate: Planner::Application.config.validate_during_duplication
      }

      copy.zonings.each{ |zoning|
        zoning.zones.each{ |zone|
          zone.vehicle = vehicles_map[zone.vehicle]
          zone.save! validate: Planner::Application.config.validate_during_duplication
        }
      }

      copy.plannings.each{ |planning|
        planning.vehicle_usage_set = vehicle_usage_sets_map[planning.vehicle_usage_set]
        planning.zonings = planning.zonings.collect{ |zoning| zonings_map[zoning] }
        planning.tags = planning.tags.collect{ |tag| tags_map[tag] }

        # All routes must be caught in memory, don't use scopes
        planning.routes.each{ |route|
          route.vehicle_usage = vehicle_usages_map[route.vehicle_usage]
          route.quantities = Hash[route.quantities.to_a.map{ |q| deliverable_unit_ids_map[q[0]] && [deliverable_unit_ids_map[q[0]].id, q[1]] }.compact]

          route.stops.each{ |stop|
            stop.visit = visits_map[stop.visit]
            stop.save! validate: Planner::Application.config.validate_during_duplication
          }
          route.save! validate: Planner::Application.config.validate_during_duplication
        }
        planning.force_check_consistency = true
        planning.save! validate: Planner::Application.config.validate_during_duplication
      }

      copy.stops_relations.each{ |relation|
        relation.current = visits_map[relation.current]
        relation.successor = visits_map[relation.successor]
        relation.save! validate: Planner::Application.config.validate_during_duplication
      }
      column_def = copy.advanced_options.dig('import', 'destinations', 'spreadsheetColumnsDef')
      if column_def.present?
        column_def.keys.select{ |key| key.start_with?('quantity') }.each do |key|
          prefix = key.start_with?('quantity_operation') ? 'quantity_operation' : 'quantity'
          d_id = deliverable_unit_ids_map[key.delete_prefix(prefix).to_i].id
          column_def["#{prefix}#{d_id}"] = column_def.delete(key)
        end
      end

      copy.save! validate: Planner::Application.config.validate_during_duplication
      copy.reload
    })
  end

  def duplicate
    Customer.transaction do
      Route.no_touching do
        copy = self.amoeba_dup
        copy.name += " (#{I18n.l(Time.zone.now, format: :long)})"
        copy.ref = copy.ref ? Time.new.to_i.to_s : nil
        copy.test = Planner::Application.config.customer_test_default
        copy.save! validate: Planner::Application.config.validate_during_duplication
        copy
      end
    end
  end

  def assign_device
    @device = Device.new(self)
  end

  def devices
    if self[:devices].respond_to?('deep_symbolize_keys!')
      self[:devices].deep_symbolize_keys!
    else
      self[:devices]
    end
  end

  def default_position
    store = stores.find{ |s| !s.lat.nil? && !s.lng.nil? }
    # store ? [store.lat, store.lng] : [I18n.t('stores.default.lat'), I18n.t('stores.default.lng')]
    {lat: store ? store.lat : I18n.t('stores.default.lat'), lng: store ? store.lng : I18n.t('stores.default.lng')}
  end

  def delete_all_destinations
    stops_relations.delete_all
    destinations.delete_all
    self.reload
    reindex_routes
  end

  def delete_all_visits
    Visit.where(id: visits.map(&:id)).delete_all
    self.reload
    reindex_routes
  end

  def is_editable?
    destinations.count <= Planner::Application.config.max_destinations_editable
  end

  def max_vehicles
    @max_vehicles ||= vehicles.size
  end

  def max_vehicles=(max)
    unless max.blank?
      @max_vehicles = Integer(max.to_s, 10)
    end
  rescue ArgumentError
    @invalid_max_vehicle = true
  end

  def default_max_plannings
    [Rails.configuration.max_plannings, max_plannings || Rails.configuration.max_plannings_default].compact.min
  end

  def too_many_plannings?
    default_max_plannings && default_max_plannings <= self.plannings.count
  end

  def default_max_zonings
    [Rails.configuration.max_zonings, max_zonings || Rails.configuration.max_zonings_default].compact.min
  end

  def too_many_zonings?
    default_max_zonings && default_max_zonings <= self.zonings.count
  end

  def default_max_destinations
    [Rails.configuration.max_destinations, max_destinations || Rails.configuration.max_destinations_default].compact.min
  end

  def too_many_destinations?
    default_max_destinations && default_max_destinations <= self.destinations.count
  end

  def default_max_vehicle_usage_sets
    [Rails.configuration.max_vehicle_usage_sets, max_vehicle_usage_sets || Rails.configuration.max_vehicle_usage_sets_default].compact.min
  end

  def too_many_vehicle_usage_sets?
    default_max_vehicle_usage_sets && default_max_vehicle_usage_sets <= self.vehicle_usage_sets.count
  end

  def stores_by_distance(position, n, vehicle_usage = nil, &matrix_progress)
    starts = [[position.lat, position.lng]]
    dests = self.stores.select{ |store| !store.lat.nil? && !store.lng.nil? }.collect{ |store| [store.lat, store.lng] }
    r = (vehicle_usage && vehicle_usage.vehicle.default_router) || router
    d = (vehicle_usage && vehicle_usage.vehicle.default_router_dimension) || router_dimension
    options = (vehicle_usage && vehicle_usage.vehicle.default_router_options || router_options).symbolize_keys
    options[:geometry] = false
    options[:speed_multiplier] = (vehicle_usage && vehicle_usage.vehicle.default_speed_multiplier) || speed_multiplier || 1

    distances = r.matrix(starts, dests, :distance, options, &matrix_progress)[0]
    stores.select{ |store, distance| !distance.nil? }.zip(distances).sort_by{ |store, distance|
      distance
    }[0..[n, stores.size].min - 1].collect{ |store, distance| store }
  end

  def destinations_inside_time_distance(position, distance, time, vehicle_usage = nil, &matrix_progress)
    starts = [[position.lat, position.lng]]
    dest_with_pos = self.destinations.select{ |d| !d.lat.nil? && !d.lng.nil? }
    dests = dest_with_pos.collect{ |d| [d.lat, d.lng] }
    r = (vehicle_usage && vehicle_usage.vehicle.default_router) || router
    d = (vehicle_usage && vehicle_usage.vehicle.default_router_dimension) || router_dimension
    options = (vehicle_usage && vehicle_usage.vehicle.default_router_options || router_options).symbolize_keys
    options[:geometry] = false
    options[:speed_multiplier] = (vehicle_usage && vehicle_usage.vehicle.default_speed_multiplier) || speed_multiplier || 1

    distances = !distance.nil? && r.distance? ? r.matrix(starts, dests, :distance, options, &matrix_progress)[0] : []
    times = !time.nil? && r.time? ? r.matrix(starts, dests, :time, options, &matrix_progress)[0] : []
    dest_with_pos.zip(distances, times).select{ |dest, dist, t|
      (!dist || dist[0] <= distance) && (!t || t[0] <= time)
    }.collect{ |dest, d, t| dest }
  end

  private

  def reindex_routes
    Route.includes_stops.scoping do
      plannings.reload.each { |p|
        p.routes.each do |route|
          # reindex remaining stops (like rests)
          route.force_reindex
          route.outdated = true if !route.geojson_points.try(&:empty?) || !route.geojson_tracks.try(&:empty?)
        end
        p.save!
      }
    end
  end

  def devices_update_vehicles
    # Remove device association on vehicles if devices credentials have changed
    vehicles_with_devices = self.vehicles.select(&:devices)
    Planner::Application.config.devices.to_h.each{ |device_name, device_object|
      next unless device_object.respond_to?('definition')

      device_definition = device_object.definition
      next if !device_definition.dig(:forms, :settings) || !device_definition.dig(:forms, :vehicle)

      if send("#{device_name}_changed?")
        device_definition.dig(:forms, :vehicle).keys.each{ |key|
          vehicles_with_devices.each{ |vehicle|
            vehicle.devices[key] = nil
          }
        }
      end
    }
  end

  Planner::Application.config.devices.to_h.each{ |device_name, device_object|
    if device_object.respond_to?('definition')
      device_definition = device_object.definition
      if device_definition.key?(:forms) && device_definition[:forms].key?(:settings)

        define_method("#{device_name}_changed?") do
          before = self.changed.include?('devices') ? self.changes[:devices].first : nil
          after = self.changed.include?('devices') ? self.changes[:devices].second : nil

          if self.changed.include?('devices') && !before.nil? && !after.nil?
            if after.include?(device_name) && before.include?(device_name)
              device_definition[:forms][:settings].keys.each{ |key|
                return true if after[device_name][key] != before[device_name][key] || after[device_name][:enable] != before[device_name][:enable]
              }
            end
          end

          false
        end

      end
    end
  }

  def assign_defaults
    self.default_country ||= I18n.t('customers.default.country')
    self.enable_references ||= Planner::Application.config.enable_references
  end

  def create_default_store
    stores.create(
      name: I18n.t('stores.default.name'),
      city: I18n.t('stores.default.city'),
      lat: Float(I18n.t('stores.default.lat')),
      lng: Float(I18n.t('stores.default.lng'))
    )
  end

  def create_default_vehicle_usage_set
    vehicle_usage_sets.create(
      name: I18n.t('vehicle_usage_sets.default.name'),
      store_start: stores[0],
      store_stop: stores[0]
    )
  end

  def create_default_deliverable_unit
    deliverable_units.create(
      default_quantity: 1
    )
  end

  def update_outdated
    if optimization_force_start_changed? || visit_duration_changed? || destination_duration_changed? || router_id_changed? || router_dimension_changed? || router_options_changed? || speed_multiplier_changed? || @deliverable_units_updated
      plannings.each { |planning|
        planning.routes.each { |route|
          route.outdated = true
        }
      }
    end
  end

  def update_deliverable_units_track(_deliverable_unit)
    @deliverable_units_updated = true
  end

  def update_max_vehicles
    if max_vehicles != vehicles.size
      if vehicles.size < max_vehicles
        # Add new
        (max_vehicles - vehicles.size).times{ |_i|
          vehicles.build(name: I18n.t('vehicles.default_name', n: vehicles.size + 1))
        }
      elsif vehicles.size > max_vehicles
        # Delete
        (vehicles.size - max_vehicles).times{ |_i|
          vehicle = vehicles[vehicles.size - 1]
          vehicles.destroy(vehicle)
        }
      end
      @max_vehicles = vehicles.size
    end
  end

  def sanitize_print_header
    self.print_header = Sanitize.fragment(print_header, Sanitize::Config::RELAXED)
  end

  def nilify_router_options_blanks
    true_options = router.options.select { |_, v| v == true }.keys
    write_attribute :router_options, self.router_options.delete_if { |k, v| v.to_s.empty? || true_options.exclude?(k) }
  end

  def destroy_disable_vehicle_usage_sets_validation
    vehicle_usage_sets.each{ |vehicle_usage_set|
      def vehicle_usage_set.destroy_vehicle_usage_set
        # Avoid validation of at least one vehicle_usage_set by customer
      end
    }
  end

  def check_router_options_format
    self.router_options.each do |k, v|
      if k == 'distance' || k == 'weight' || k == 'weight_per_axle' || k == 'height' || k == 'width' || k == 'length' || k == 'max_walk_distance'
        self.router_options[k] = Customer.to_delocalized_decimal(v) if v.is_a?(String)
      end
    end
  end

  def validate_plannings_count
    if self.default_max_plannings && self.default_max_plannings < self.plannings.count
      errors.add(:max_plannings, I18n.t('activerecord.errors.models.customer.attributes.plannings.over_max_limit'))
      false
    end
  end

  def validate_zonings_count
    if self.default_max_zonings && self.default_max_zonings < self.zonings.count
      errors.add(:max_zonings, I18n.t('activerecord.errors.models.customer.attributes.zonings.over_max_limit'))
      false
    end
  end

  def validate_destinations_count
    if self.default_max_destinations && self.default_max_destinations < self.destinations.count
      errors.add(:max_destinations, I18n.t('activerecord.errors.models.customer.attributes.destinations.over_max_limit'))
      false
    end
  end

  def validate_vehicle_usage_sets_count
    if self.default_max_vehicle_usage_sets && self.default_max_vehicle_usage_sets < self.vehicle_usage_sets.count
      errors.add(:max_vehicle_usage_sets, I18n.t('activerecord.errors.models.customer.attributes.vehicle_usage_sets.over_max_limit'))
      false
    end
  end

  def validate_optimization_times
    optimization_minimal_time = self.optimization_minimal_time || Planner::Application.config.optimize_minimal_time
    optimization_time = self.optimization_time || Planner::Application.config.optimize_time

    if optimization_minimal_time && optimization_time && optimization_time < optimization_minimal_time
      errors.add(:optimization_time, I18n.t('activerecord.errors.models.optimization_time.must_be_greater_than_minimal_time'))
      false
    end
  end

  def router_belong_to_profile
    return true if profile && profile.routers.exists?(router_id)
    errors.add(:router, I18n.t('activerecord.errors.models.router.unauthorized'))
    false
  end
end
