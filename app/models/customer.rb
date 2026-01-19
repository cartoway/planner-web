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
  before_destroy :delete_all_plannings # Declare and run before has_many :plannings
  has_many :plannings, inverse_of: :customer, autosave: true
  has_many :order_arrays, inverse_of: :customer, autosave: true, dependent: :delete_all
  has_many :zonings, inverse_of: :customer, dependent: :delete_all
  before_destroy :destroy_disable_vehicle_usage_sets_validation # Declare and run before has_many :vehicle_usage_sets
  has_many :vehicle_usage_sets, inverse_of: :customer, autosave: true, dependent: :destroy
  has_many :vehicles, inverse_of: :customer, autosave: true, dependent: :delete_all
  has_many :stores, inverse_of: :customer, autosave: true, dependent: :delete_all
  has_many :store_reloads, through: :stores
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
  store_accessor :advanced_options, :import, :solver_priority

  include LocalizedAttr # To use to_delocalized_decimal method

  nilify_blanks
  auto_strip_attributes :name, :print_header, :default_country, :print_barcode, :sms_template

  include TimeAttr
  attribute :visit_duration, ScheduleType.new
  attribute :destination_duration, ScheduleType.new
  attribute :store_reload_duration, ScheduleType.new
  attribute :stop_max_upper_bound, ScheduleType.new
  attribute :vehicle_max_upper_bound, ScheduleType.new
  time_attr :visit_duration, :destination_duration, :stop_max_upper_bound, :store_reload_duration, :vehicle_max_upper_bound

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
  validates :optimization_dicho_minimum_service_size, numericality: true, allow_nil: true
  validate :validate_optimization_dicho_minimum_service_size
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
  scope :for_duplication, -> {
    preload(
      :custom_attributes,
      :messaging_logs,
      :deliverable_units,
      :tags,
      :users,
      { vehicles: [:vehicle_usages, :tags, :tag_vehicles] },
      {
        vehicle_usage_sets: [
          :store_start, :store_stop, :store_rest, :store_reloads,
          { vehicle_usages: [:store_start, :store_stop, :store_rest, :store_reloads, :tags, :tag_vehicle_usages] }
        ]
      },
      { stores: { store_reloads: [:vehicle_usages, :vehicle_usage_sets] } },
      {
        destinations: [
          :tags,
          { visits: [:tags, :tag_visits] }
        ]
      },
      { zonings: { zones: :vehicle } },
      { stops_relations: [:current, :successor] },
      {
        plannings: [
          :vehicle_usage_set, :zonings, :tags, :tag_plannings,
          {
            routes: [
              :vehicle_usage, :route_data, :route_geojson, :start_route_data, :stop_route_data,
              { stops: [:route_data, :store, :visit, :store_reload] }
            ]
          }
        ]
      }
    )
  }

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
      # Build store_reloads_map by iterating through stores in order to preserve mapping
      store_reloads_map = {}
      original.stores.zip(copy.stores).each do |original_store, copy_store|
        original_store.store_reloads.zip(copy_store.store_reloads).each do |original_reload, copy_reload|
          store_reloads_map[original_reload] = copy_reload if original_reload && copy_reload
        end
      end
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
        vehicle_usage_set.store_reloads = vehicle_usage_set.store_reloads.map{ |store_reload| store_reloads_map[store_reload] }

        vehicle_usage_set.vehicle_usages.each{ |vehicle_usage|
          vehicle_usage.vehicle = vehicles_map[vehicle_usage.vehicle]
          vehicle_usage.store_start = stores_map[vehicle_usage.store_start]
          vehicle_usage.store_stop = stores_map[vehicle_usage.store_stop]
          vehicle_usage.store_rest = stores_map[vehicle_usage.store_rest]
          vehicle_usage.store_reloads = vehicle_usage.store_reloads.map{ |store_reload| store_reloads_map[store_reload] }
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
          visit.pickups = Hash[visit.pickups.to_a.map{ |q| deliverable_unit_ids_map[q[0]] && [deliverable_unit_ids_map[q[0]].id, q[1]] }.compact]
          visit.deliveries = Hash[visit.deliveries.to_a.map{ |q| deliverable_unit_ids_map[q[0]] && [deliverable_unit_ids_map[q[0]].id, q[1]] }.compact]
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
          route.route_data.pickups = Hash[route.route_data.pickups.to_a.map{ |q| deliverable_unit_ids_map[q[0]] && [deliverable_unit_ids_map[q[0]].id, q[1]] }.compact]
          route.route_data.deliveries = Hash[route.route_data.deliveries.to_a.map{ |q| deliverable_unit_ids_map[q[0]] && [deliverable_unit_ids_map[q[0]].id, q[1]] }.compact]

          route.stops.each{ |stop|
            case stop
            when StopStore
              stop.store_reload = store_reloads_map[stop.store_reload]
            when StopVisit
              stop.visit = visits_map[stop.visit]
            when StopRest
              stop.store = stores_map[stop.store]
            end
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
        %w(pickup delivery).each do |prefix|
          column_def.keys.select{ |key| key.start_with?(prefix) }.each do |key|
            d_id = deliverable_unit_ids_map[key.delete_prefix(prefix).to_i].id
            column_def["#{prefix}#{d_id}"] = column_def.delete(key)
          end
        end
      end

      copy.save! validate: Planner::Application.config.validate_during_duplication
      copy.reload

      # Update counters
      Customer.where(id: copy.id).update_all(
        destinations_count: Destination.where(customer_id: copy.id).count,
        plannings_count: Planning.where(customer_id: copy.id).count,
        vehicles_count: Vehicle.where(customer_id: copy.id).count,
        visits_count: Visit.joins(:destination).where(destinations: { customer_id: copy.id }).count
      )
      copy.reload
    })
  end

  def duplicate
    customer_id = self.custom_duplicate
    Customer.find(customer_id)
  end

  def custom_duplicate
    Customer.transaction do
      attributes = self.import_attributes.except('id', 'job_destination_geocoding_id', 'job_store_geocoding_id', 'job_optimizer_id')
      attributes['name'] += " (#{I18n.l(Time.zone.now, format: :long)})"
      attributes['test'] = Planner::Application.config.customer_test_default
      attributes['ref'] = attributes['ref'] ? Time.new.to_i.to_s : nil

      customer_id = Customer.import([attributes], validate: false).ids.first

      new_deliverable_unit_attributes = self.deliverable_units.map{ |deliverable_unit| deliverable_unit.import_attributes.except('id').merge('customer_id'=> customer_id) }
      deliverable_unit_import_result = DeliverableUnit.import(new_deliverable_unit_attributes, validate: false)
      deliverable_unit_ids_map = Hash[self.deliverable_units.map(&:id).zip(deliverable_unit_import_result.ids)]

      new_vehicle_attributes = self.vehicles.map{ |vehicle| vehicle.import_attributes.except('id').merge('customer_id'=> customer_id) }
      new_vehicles = new_vehicle_attributes.map{ |vehicle| Vehicle.new(vehicle) }
      new_vehicles.each { |vehicle|
        vehicle.capacities = Hash[vehicle.capacities.to_a.map{ |q| deliverable_unit_ids_map[q[0].to_i] && [deliverable_unit_ids_map[q[0].to_i], q[1]] }.compact]
        vehicle.reset_driver_token
      }
      vehicle_import_result = Vehicle.import(new_vehicles.map(&:import_attributes), validate: false)
      vehicle_ids_map = Hash[self.vehicles.map(&:id).zip(vehicle_import_result.ids)]

      new_store_attributes = self.stores.map{ |store| store.import_attributes.except('id').merge('customer_id'=> customer_id) }
      store_import_result = Store.import(new_store_attributes, validate: false)
      store_ids_map = Hash[self.stores.map(&:id).zip(store_import_result.ids)]

      new_store_reload_attributes = self.store_reloads.map{ |store_reload| store_reload.import_attributes.except('id').merge('store_id'=> store_ids_map[store_reload.store_id]) }
      store_reload_import_result = StoreReload.import(new_store_reload_attributes, validate: false)
      store_reload_ids_map = Hash[self.store_reloads.map(&:id).zip(store_reload_import_result.ids)]

      new_destination_attributes = self.destinations.map{ |destination| destination.import_attributes.except('id').merge('customer_id'=> customer_id) }
      destination_import_result = Destination.import(new_destination_attributes, validate: false)
      destination_ids_map = Hash[self.destinations.map(&:id).zip(destination_import_result.ids)]

      old_visits = self.destinations.flat_map{ |destination| destination.visits.to_a }
      new_visit_attributes = old_visits.map{ |visit| visit.import_attributes.except('id') }
      new_visit_attributes.each { |visit|
        visit['destination_id'] = destination_ids_map[visit['destination_id']]
        visit['pickups'] = Hash[visit['pickups'].to_a.map{ |q| deliverable_unit_ids_map[q[0].to_i] && [deliverable_unit_ids_map[q[0].to_i], q[1]] }.compact]
        visit['deliveries'] = Hash[visit['deliveries'].to_a.map{ |q| deliverable_unit_ids_map[q[0].to_i] && [deliverable_unit_ids_map[q[0].to_i], q[1]] }.compact]
      }
      visit_import_result = Visit.import(new_visit_attributes, validate: false)
      visit_ids_map = Hash[old_visits.map(&:id).zip(visit_import_result.ids)]

      new_custom_attribute_attributes = self.custom_attributes.map{ |custom_attribute| custom_attribute.import_attributes.except('id').merge('customer_id'=> customer_id) }
      CustomAttribute.import(new_custom_attribute_attributes, validate: false)

      new_messaging_log_attributes = self.messaging_logs.map{ |messaging_log| messaging_log.import_attributes.except('id').merge('customer_id'=> customer_id) }
      MessagingLog.import(new_messaging_log_attributes, validate: false)

      new_vehicle_usage_set_attributes = self.vehicle_usage_sets.map{ |vehicle_usage_set| vehicle_usage_set.import_attributes.except('id') }
      new_vehicle_usage_set_attributes.each { |vehicle_usage_set|
        vehicle_usage_set['customer_id'] = customer_id
        vehicle_usage_set['store_start_id'] = store_ids_map[vehicle_usage_set['store_start_id']]
        vehicle_usage_set['store_stop_id'] = store_ids_map[vehicle_usage_set['store_stop_id']]
        vehicle_usage_set['store_rest_id'] = store_ids_map[vehicle_usage_set['store_rest_id']]
      }
      vehicle_usage_set_import_result = VehicleUsageSet.import(new_vehicle_usage_set_attributes, validate: false)
      vehicle_usage_set_ids_map = Hash[self.vehicle_usage_sets.map(&:id).zip(vehicle_usage_set_import_result.ids)]

      new_planning_attributes = self.plannings.map{ |planning| planning.import_attributes.except('id') }
      new_planning_attributes.each { |planning|
        planning['customer_id'] = customer_id
        planning['vehicle_usage_set_id'] = vehicle_usage_set_ids_map[planning['vehicle_usage_set_id']]
      }
      planning_import_result = Planning.import(new_planning_attributes, validate: false)
      planning_ids_map = Hash[self.plannings.map(&:id).zip(planning_import_result.ids)]

      new_zoning_attributes = self.zonings.map{ |zoning| zoning.import_attributes.except('id').merge('customer_id'=> customer_id) }
      zoning_import_result = Zoning.import(new_zoning_attributes, validate: false)
      zoning_ids_map = Hash[self.zonings.map(&:id).zip(zoning_import_result.ids)]

      new_zone_attributes = self.zonings.flat_map{ |zoning| zoning.zones.map{ |zone| zone.import_attributes.except('id') } }
      new_zone_attributes.each { |zone|
        zone['zoning_id'] = zoning_ids_map[zone['zoning_id']]
        zone['vehicle_id'] = vehicle_ids_map[zone['vehicle_id']]
      }
      Zone.import(new_zone_attributes, validate: false)

      new_stop_relation_attributes = self.stops_relations.map{ |stop_relation| stop_relation.import_attributes.except('id').merge('customer_id'=> customer_id, 'current_id'=> visit_ids_map[stop_relation.current_id], 'successor_id'=> visit_ids_map[stop_relation.successor_id]) }
      StopsRelation.import(new_stop_relation_attributes, validate: false)

      new_tag_attributes = self.tags.map{ |tag| tag.import_attributes.except('id').merge('customer_id'=> customer_id) }
      tag_import_result = Tag.import(new_tag_attributes, validate: false)
      tag_ids_map = Hash[self.tags.map(&:id).zip(tag_import_result.ids)]

      new_tag_destination_attributes = self.tags.flat_map{ |tag|
        tag.destinations.select{ |destination| destination_ids_map[destination.id] }.map{ |destination|
          { 'tag_id'=> tag_ids_map[tag.id], 'destination_id'=> destination_ids_map[destination.id] }
        }
      }
      TagDestination.import(new_tag_destination_attributes, validate: false) if new_tag_destination_attributes.any?

      new_tag_visits_attributes = self.tags.flat_map{ |tag|
        tag.visits.select{ |visit| visit_ids_map[visit.id] }.map{ |visit|
          { 'tag_id'=> tag_ids_map[tag.id], 'visit_id'=> visit_ids_map[visit.id] }
        }
      }
      TagVisit.import(new_tag_visits_attributes, validate: false) if new_tag_visits_attributes.any?

      new_tag_planning_attributes = self.tags.flat_map{ |tag|
        tag.plannings.select{ |planning| planning_ids_map[planning.id] }.map{ |planning|
          { 'tag_id'=> tag_ids_map[tag.id], 'planning_id'=> planning_ids_map[planning.id] }
        }
      }
      TagPlanning.import(new_tag_planning_attributes, validate: false) if new_tag_planning_attributes.any?

      new_tag_vehicle_attributes = self.tags.flat_map{ |tag|
        tag.vehicles.select{ |vehicle| vehicle_ids_map[vehicle.id] }.map{ |vehicle|
          { 'tag_id'=> tag_ids_map[tag.id], 'vehicle_id'=> vehicle_ids_map[vehicle.id] }
        }
      }
      TagVehicle.import(new_tag_vehicle_attributes, validate: false) if new_tag_vehicle_attributes.any?

      unless self.exclude_users
        new_user_attributes = self.users.map{ |user| user.import_attributes.except('encrypted_password', 'id').merge('customer_id'=> customer_id) }
        new_users = new_user_attributes.map do |user|
          new_user = User.new(user)
          new_user.api_key_random
          new_user.email = I18n.l(Time.zone.now, format: '%Y%m%d%H%M%S') + '_' + new_user.email
          new_user.password = Devise.friendly_token

          # --------------------------
          #  Clean devise operations
          # --------------------------
          new_user.confirmed_at = nil
          new_user.confirmation_token = nil
          new_user.confirmation_sent_at = nil
          new_user.reset_password_token = nil
          new_user.reset_password_sent_at = nil
          new_user.sign_in_count = 0
          new_user.current_sign_in_at = nil
          new_user.last_sign_in_at = nil
          new_user.current_sign_in_ip = nil
          new_user.last_sign_in_ip = nil
          new_user.generate_confirmation_token
          new_user
        end
        User.import(new_users, validate: false)
      end

      vehicle_usages = self.vehicle_usage_sets.flat_map{ |vehicle_usage_set| vehicle_usage_set.vehicle_usages }
      new_vehicle_usage_attributes = vehicle_usages.map{ |vehicle_usage| vehicle_usage.import_attributes.except('id') }
      new_vehicle_usage_attributes.each { |vehicle_usage|
        vehicle_usage['vehicle_usage_set_id'] = vehicle_usage_set_ids_map[vehicle_usage['vehicle_usage_set_id']]
        vehicle_usage['vehicle_id'] = vehicle_ids_map[vehicle_usage['vehicle_id']]
        vehicle_usage['store_start_id'] = store_ids_map[vehicle_usage['store_start_id']]
        vehicle_usage['store_stop_id'] = store_ids_map[vehicle_usage['store_stop_id']]
        vehicle_usage['store_rest_id'] = store_ids_map[vehicle_usage['store_rest_id']]
      }
      vehicle_usage_import_result = VehicleUsage.import(new_vehicle_usage_attributes, validate: false)
      vehicle_usage_ids_map = Hash[vehicle_usages.map(&:id).zip(vehicle_usage_import_result.ids)]

      new_tag_vehicle_usage_attributes = self.tags.flat_map{ |tag|
        tag.vehicle_usages.select{ |vehicle_usage| vehicle_usage_ids_map[vehicle_usage.id] }.map{ |vehicle_usage|
          { 'tag_id'=> tag_ids_map[tag.id], 'vehicle_usage_id'=> vehicle_usage_ids_map[vehicle_usage.id] }
        }
      }
      TagVehicleUsage.import(new_tag_vehicle_usage_attributes, validate: false) if new_tag_vehicle_usage_attributes.any?

      old_route_data = self.plannings.flat_map{ |planning|
        planning.routes.flat_map{ |route|
          route.stops.map{ |stop| stop.route_data }.compact.map{ |route_data| route_data } +
            [route.route_data, route.start_route_data, route.stop_route_data].compact.map{ |route_data| route_data }
        }
      }
      new_route_data_attributes = old_route_data.map{ |route_data| route_data.import_attributes.except('id', 'route_id') }
      new_route_data_attributes.each { |route_data|
        route_data['pickups'] = Hash[route_data['pickups'].to_a.map{ |q| deliverable_unit_ids_map[q[0]] && [deliverable_unit_ids_map[q[0]].id, q[1]] }.compact]
        route_data['deliveries'] = Hash[route_data['deliveries'].to_a.map{ |q| deliverable_unit_ids_map[q[0]] && [deliverable_unit_ids_map[q[0]].id, q[1]] }.compact]
      }
      route_data_import_result = RouteData.import(new_route_data_attributes, validate: false)
      route_data_ids_map = Hash[old_route_data.map(&:id).zip(route_data_import_result.ids)]

      old_routes = self.plannings.flat_map{ |planning| planning.routes }
      new_route_attributes = old_routes.map{ |route| route.import_attributes.except('id') }
      new_route_attributes.each { |route|
        route['planning_id'] = planning_ids_map[route['planning_id']]
        route['vehicle_usage_id'] = vehicle_usage_ids_map[route['vehicle_usage_id']]
        route['route_data_id'] = route_data_ids_map[route['route_data_id']]
        route['start_route_data_id'] = route_data_ids_map[route['start_route_data_id']]
        route['stop_route_data_id'] = route_data_ids_map[route['stop_route_data_id']]
      }
      route_import_result = Route.import(new_route_attributes, validate: false)
      route_ids_map = Hash[old_routes.map(&:id).zip(route_import_result.ids)]

      new_route_geojson_attributes = old_routes.map{ |route| route.route_geojson.import_attributes.except('id') }
      new_route_geojson_attributes.each { |route_geojson|
        route_geojson['route_id'] = route_ids_map[route_geojson['route_id']]
      }
      RouteGeojson.import(new_route_geojson_attributes, validate: false)

      new_stop_attributes = old_routes.flat_map{ |route| route.stops }.map{ |stop| stop.import_attributes.except('id') }
      new_stop_attributes.each { |stop|
        stop['route_id'] = route_ids_map[stop['route_id']]
        stop['store_id'] = store_ids_map[stop['store_id']]
        stop['visit_id'] = visit_ids_map[stop['visit_id']]
        stop['store_reload_id'] = store_reload_ids_map[stop['store_reload_id']]
        stop['route_data_id'] = route_data_ids_map[stop['route_data_id']]
        stop['loads'] = Hash[stop['loads'].to_a.map{ |q| deliverable_unit_ids_map[q[0]] && [deliverable_unit_ids_map[q[0]].id, q[1]] }.compact]
      }
      Stop.import(new_stop_attributes, validate: false)

      new_planning_zonings_attributes = self.plannings.flat_map { |planning|
        planning.zonings.map{ |zoning| {'planning_id'=> planning_ids_map[planning.id], 'zoning_id'=> zoning_ids_map[zoning.id]} }
      }
      PlanningsZoning.import(new_planning_zonings_attributes, validate: false) if new_planning_zonings_attributes.any?

      new_store_reload_vehicle_usage_set_attributes = self.store_reloads.flat_map { |store_reload|
        store_reload.vehicle_usage_sets.map{ |vehicle_usage_set| {'store_reload_id'=> store_reload_ids_map[store_reload.id], 'vehicle_usage_set_id'=> vehicle_usage_set_ids_map[vehicle_usage_set.id]} }
      }
      StoreReloadVehicleUsageSet.import(new_store_reload_vehicle_usage_set_attributes, validate: false) if new_store_reload_vehicle_usage_set_attributes.any?

      new_store_reload_vehicle_usage_attributes = self.store_reloads.flat_map { |store_reload|
        store_reload.vehicle_usages.map{ |vehicle_usage| {'store_reload_id'=> store_reload_ids_map[store_reload.id], 'vehicle_usage_id'=> vehicle_usage_ids_map[vehicle_usage.id]} }
      }
      StoreReloadVehicleUsage.import(new_store_reload_vehicle_usage_attributes, validate: false) if new_store_reload_vehicle_usage_attributes.any?

      customer_id
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

  def delete_destinations(ids)
    destinations.where(id: ids).delete_all
    self.reload
    reindex_routes
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

  def delete_all_plannings
    planning_ids = plannings.pluck(:id)
    route_ids = Route.where(planning_id: planning_ids).pluck(:id)

    RouteGeojson.where(route_id: route_ids).delete_all if route_ids.any?
    Stop.where(route_id: route_ids).delete_all if route_ids.any?
    Planning.where(customer_id: id).destroy_all
  end

  def is_editable?
    destinations_count <= Planner::Application.config.max_destinations_editable
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
    default_max_destinations && default_max_destinations <= self.destinations_count
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
      default_delivery: 1
    )
  end

  def update_outdated
    if optimization_force_start_changed? || visit_duration_changed? || destination_duration_changed? || store_reload_duration_changed? || router_id_changed? || router_dimension_changed? || router_options_changed? || speed_multiplier_changed? || @deliverable_units_updated
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
    if self.default_max_destinations && self.default_max_destinations < self.destinations_count
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

  def validate_optimization_dicho_minimum_service_size
    return unless optimization_dicho_minimum_service_size.present? && optimization_max_split_size.present?

    if optimization_dicho_minimum_service_size > optimization_max_split_size
      errors.add(:optimization_dicho_minimum_service_size, I18n.t('activerecord.errors.models.customer.attributes.optimization_dicho_minimum_service_size.must_be_less_than_max_split_size'))
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
