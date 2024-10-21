# Copyright © Mapotempo, 2016
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
require 'coerce'

module SharedParams # rubocop:disable Metrics/ModuleLength
  extend Grape::API::Helpers

  params :request_capacity do |options|
    optional :deliverable_unit_id, type: Integer
    optional :quantity, type: Float, coerce_with: CoerceFloatString
    all_or_none_of :deliverable_unit_id, :quantity
  end

  params :request_customer do |options|
    optional :end_subscription, type: Date, documentation: { desc: EDIT_ONLY_ADMIN }
    optional :max_vehicles, type: Integer, documentation: { desc: EDIT_ONLY_ADMIN }

    if options[:required_customer_params]
      requires :name, type: String, documentation: { desc: EDIT_ONLY_ADMIN }
      requires :default_country, type: String
      requires :router_id, type: Integer
      requires :profile_id, type: String, documentation: { desc: EDIT_ONLY_ADMIN }
    else
      optional :name, type: String, documentation: { desc: EDIT_ONLY_ADMIN }
      optional :default_country, type: String
      optional :router_id, type: Integer
      optional :profile_id, type: String, documentation: { desc: EDIT_ONLY_ADMIN }
    end

    # Default
    optional :store_ids, type: Array[Integer]
    optional :vehicle_usage_set_ids, type: Array[Integer]
    optional :deliverable_unit_ids, type: Array[Integer]

    optional :ref, type: String, documentation: { desc: EDIT_ONLY_ADMIN }
    optional :visit_duration, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :take_over, type: Integer, documentation: { hidden: true, type: 'string', desc: '[Deprecated] Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    mutually_exclusive :visit_duration, :take_over

    optional :router_dimension, type: String, values: ::Router::DIMENSION.keys.map(&:to_s)
    optional :router_options, type: Hash, documentation: { param_type: 'body' } do
      use(:request_router_options, options)
    end
    optional :speed_multiplier, type: Float, coerce_with: CoerceFloatString
    optional :speed_multiplicator, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Deprecated, use speed_multiplier instead.', hidden: true }
    mutually_exclusive :speed_multiplier, :speed_multiplicator
    optional :history_cron_hour, type: Integer

    optional :print_planning_annotating, type: Boolean
    optional :print_header, type: String
    optional :print_barcode, type: String, values: ::Customer::PRINT_BARCODE, documentation: { desc: 'Print the Reference as Barcode'}
    optional :sms_template, type: String
    optional :sms_concat, type: Boolean
    optional :sms_from_customer_name, type: Boolean

    optional :optimization_max_split_size, type: Integer, documentation: { desc: 'Maximum number of visits to split problem', example: Mapotempo::Application.config.optimize_max_split_size }
    optional :optimization_cluster_size, type: Integer, documentation: { desc: 'Time in seconds to group near visits', example: Mapotempo::Application.config.optimize_cluster_size }
    optional :optimization_time, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Maximum optimization time (by vehicle)', example: Mapotempo::Application.config.optimize_time }
    optional :optimization_minimal_time, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Minimum optimization time (by vehicle)', example: Mapotempo::Application.config.optimize_minimal_time}
    optional :optimization_stop_soft_upper_bound, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Stops delay coefficient, 0 to avoid delay', example: Mapotempo::Application.config.optimize_stop_soft_upper_bound}
    optional :optimization_vehicle_soft_upper_bound, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Vehicles delay coefficient, 0 to avoid delay', example: Mapotempo::Application.config.optimize_vehicle_soft_upper_bound }
    optional :optimization_cost_waiting_time, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Coefficient to manage waiting time', example: Mapotempo::Application.config.optimize_cost_waiting_time }
    optional :optimization_force_start, type: Boolean, documentation: { desc: 'Force time for departure', example: Mapotempo::Application.config.optimize_force_start }

    optional :advanced_options, type: JSON, documentation: { desc: 'Advanced options' }

    optional :devices, type: Hash, coerce_with: JSON, documentation: { desc: EDIT_ONLY_ADMIN }
  end

  params :request_destination do |options|
    optional :ref, type: String
    optional :name, type: String
    optional :street, type: String
    optional :postalcode, type: String
    optional :city, type: String
    optional :state, type: String
    optional :country, type: String
    optional :lat, type: Float, coerce_with: CoerceFloatString
    optional :lng, type: Float, coerce_with: CoerceFloatString
    optional :detail, type: String
    optional :comment, type: String
    optional :phone_number, type: String
    optional :geocoding_accuracy, type: Float
    optional :geocoding_level, type: String, values: ['point', 'house', 'street', 'intersection', 'city']
    optional :tag_ids, type: Array[Integer], coerce_with: CoerceArrayInteger, documentation: { param_type: 'form', desc: 'Ids separated by comma.' }
    optional :tags, type: Array[String], documentation: { desc: 'Tag labels separated by comma.', hidden: true }
    optional :geocoded_at,  type: Time, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(val) { val.is_a?(String) ? Time.parse(val + ' UTC') : val }
    optional :geocoder_version, type: String
    optional :visits, type: Array, documentation: { param_type: 'body' } do
      if options[:skip_visit_id].nil?
        optional :id, type: Integer, documentation: { desc: 'Required to retrieve an exising visit, if left blank a new visit will be created', hidden: options[:skip_visit_id] }
      end
      use(:request_visit, options)
    end
    optional :geocoding_accuracy, type: Float, documentation: { desc: 'Must be inside 0..1 range.' }
  end

  params :request_relation do |options|
    if options[:relation_post]
      requires :relation_type, type: String, values: %w[pickup_delivery ordered sequence same_vehicle]
      requires :current_id, type: Integer
      requires :successor_id, type: Integer
    else
      optional :relation_type, type: String, values: %w[pickup_delivery ordered sequence same_vehicle]
      optional :current_id, type: Integer
      optional :successor_id, type: Integer
    end
  end

  params :request_router_options do |options|
    optional :track, type: Boolean
    optional :low_emission_zone, type: Boolean
    optional :motorway, type: Boolean
    optional :toll, type: Boolean
    optional :trailers, type: Integer
    optional :weight, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Total weight with trailers and shipping goods, in tons' }
    optional :weight_per_axle, type: Float, coerce_with: CoerceFloatString
    optional :height, type: Float, coerce_with: CoerceFloatString
    optional :width, type: Float, coerce_with: CoerceFloatString
    optional :length, type: Float, coerce_with: CoerceFloatString
    optional :hazardous_goods, type: String, values: %w(explosive gas flammable combustible organic poison radio_active corrosive poisonous_inhalation harmful_to_water other)
    optional :max_walk_distance, type: Float, coerce_with: CoerceFloatString
    optional :approach, type: String, values: ['unrestricted', 'curb']
    optional :snap, type: Float, coerce_with: CoerceFloatString
    optional :strict_restriction, type: Boolean
  end

  params :request_store do |options|
    optional :ref, type: String
    if options[:require_store_name]
      requires :name, type: String
    else
      optional :name, type: String
    end
    optional :street, type: String
    optional :postalcode, type: String
    optional :city, type: String
    optional :state, type: String
    optional :country, type: String
    optional :lat, type: Float, coerce_with: CoerceFloatString
    optional :lng, type: Float, coerce_with: CoerceFloatString
    optional :color, type: String, documentation: { desc: "Color code with #. Default: #{Mapotempo::Application.config.store_color_default}." }
    optional :icon, type: String, documentation: { desc: "Icon name from font-awesome. Default: #{Mapotempo::Application.config.store_icon_default}." }
    optional :icon_size, type: String, values: ::Store::ICON_SIZE, documentation: { desc: "Icon size. Default: #{Mapotempo::Application.config.store_icon_size_default}." }
  end

  params :request_vehicle do |options|
    optional :ref, type: String
    optional :name, type: String
    optional :contact_email, type: String, documentation: { desc: 'Driver\'s device E-Mail. Several emails might be transmitted separated by spaces, commas or semicolons.' }
    optional :phone_number, type: String
    optional :emission, type: Float, coerce_with: CoerceFloatString
    optional :consumption, type: Integer
    optional :capacity, type: Integer, documentation: { desc: 'Deprecated, use capacities instead.'}
    optional :capacity_unit, type: String, documentation: { desc: 'Deprecated, use capacities and deliverable_unit entity instead.'}
    optional :capacities, type: Array, documentation: { param_type: 'body' } do
      use :request_capacity
    end
    optional :color, type: String, documentation: { desc: 'Color code with #. For instance: #FF0000' }
    optional :fuel_type, type: String
    optional :router_id, type: Integer
    optional :router_dimension, type: String, values: ::Router::DIMENSION.keys.map(&:to_s)
    optional :router_options, type: Hash do
      use :request_router_options
    end
    optional :speed_multiplicator, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Deprecated, use speed_multiplier instead.' }
    optional :speed_multiplier, type: Float, coerce_with: CoerceFloatString
    optional :max_distance, type: Integer, documentation: { desc: 'Maximum achievable distance in meters' }
    optional :max_ride_distance, type: Integer, documentation: { desc: 'Maximum riding distance between two stops within a route in meters' }
    optional :max_ride_duration, type: Integer, documentation: { desc: 'Maximum riding time between two stops within a route (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :tag_ids, type: Array[Integer], desc: 'Ids separated by comma.', coerce_with: CoerceArrayInteger, documentation: { param_type: 'form' }
    optional :devices, type: Hash
    optional :custom_attributes, type: Hash, documentation: { desc: 'Additional properties'}
  end

  params :request_vehicle_usage do |options|
    optional :time_window_start, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :time_window_end, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :service_time_start, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :service_time_end, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :work_time, type: Integer, documentation: { type: 'string', desc: 'Work time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :max_distance, type: Integer, documentation: { type: 'integer', desc: 'Maximum achievable distance in meters' }
    optional :rest_start, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :rest_stop, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :rest_duration, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :tag_ids, type: Array[Integer], desc: 'Ids separated by comma.', coerce_with: CoerceArrayInteger, documentation: { param_type: 'form' }

    # Deprecated fields
    optional :open, type: Integer, documentation: { hidden: true, type: 'string', desc: '[Deprecated] Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    mutually_exclusive :time_window_start, :open
    optional :close, type: Integer, documentation: { hidden: true, type: 'string', desc: '[Deprecated] Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    mutually_exclusive :time_window_end, :close
  end

  params :request_vehicle_usage_set do |options|
    optional :name, type: String, documentation: { type: String }
    optional :time_window_start, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :time_window_end, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :store_start_id, type: Integer, documentation: { type: Integer }
    optional :store_stop_id, type: Integer, documentation: { type: Integer }
    optional :service_time_start, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :service_time_end, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :work_time, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :rest_start, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :rest_stop, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :rest_duration, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :store_rest_id, type: Integer, documentation: { type: Integer }
    optional :max_distance, type: Integer, documentation: { type: Integer, desc: 'Maximum achievable distance in meters' }
    optional :max_ride_distance, type: Integer, documentation: { type: Integer, desc: 'Maximum riding distance between two stops within a route in meters' }
    optional :max_ride_duration, type: Integer, documentation: { type: 'string', desc: 'Maximum riding time between two stops within a route (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    # Deprecated fields
    optional :open, type: Integer, documentation: { hidden: true, type: 'string', desc: 'Deprecated, use `visit_duration` instead' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :close, type: Integer, documentation: { hidden: true, type: 'string', desc: 'Deprecated, use `time_window_end` instead.' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
  end

  params :request_visit do |options|
    optional :tag_ids, type: Array[Integer], coerce_with: CoerceArrayInteger, documentation: { param_type: 'form', desc: 'Ids separated by comma.' }
    optional :ref, type: String

    optional :quantities, type: Array, documentation: { param_type: 'body' } do
      optional :deliverable_unit_id, type: Integer
      optional :quantity, type: Float, coerce_with: CoerceFloatString
      all_or_none_of :deliverable_unit_id, :quantity
    end
    optional :quantity, type: Integer, documentation: { desc: 'Deprecated, use quantities instead.', hidden: true }
    optional :quantity1_1, type: Integer, documentation: { desc: 'Deprecated, use quantities instead.', hidden: true }
    optional :quantity1_2, type: Integer, documentation: { desc: 'Deprecated, use quantities instead.', hidden: true }

    optional :time_window_start_1, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :open1, type: Integer, documentation: { hidden: true, type: 'string', desc: '[Deprecated] Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    mutually_exclusive :time_window_start_1, :open1

    optional :time_window_end_1, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :close1, type: Integer, documentation: { hidden: true, type: 'string', desc: '[Deprecated] Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    mutually_exclusive :time_window_end_1, :close1

    optional :duration, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :time_window_start_2, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :open2, type: Integer, documentation: { hidden: true, type: 'string', desc: '[Deprecated] Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    mutually_exclusive :time_window_start_2, :open2

    optional :time_window_end_2, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :close2, type: Integer, documentation: { hidden: true, type: 'string', desc: '[Deprecated] Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    mutually_exclusive :time_window_end_2, :close2

    optional :force_position, type: String, values: %w[neutral always_first never_first always_final], documentation: { type: 'string', desc: 'Force the position of the visits having the same position in the route they belong to' }
    optional :custom_attributes, type: Hash, documentation: { desc: 'Additional properties'}

    # Route params related to JSON import
    if options[:json_import]
      optional :ref_vehicle, type: String
      optional :route, type: String
      optional :active, type: Boolean
    end
  end

  params :request_zone do |options|
    optional :name, type: String
    optional :vehicle_id, type: Integer
    optional :polygon, type: JSON do use :request_feature end
    optional :speed_multiplier, type: Float, coerce_with: CoerceFloatString
    optional :speed_multiplicator, type: Float, coerce_with: CoerceFloatString, documentation: { hidden: true }
    mutually_exclusive :speed_multiplier, :speed_multiplicator
  end

  params :request_feature do |options|
    requires :type, type: String, values: %w[Feature]
    optional :properties, type: Hash
    optional :geometry, type: Hash do use :request_geometry end
  end

  params :request_geometry do |options|
    requires :type, type: String, values: %w[Polygon MultiPolygon GeometryCollection]
    optional :coordinates, documentation: { hidden: true }
    optional :geometries, documentation: { hidden: true }, type: Array do use :request_single_geometry end
    exactly_one_of :coordinates, :geometries
  end

  params :request_single_geometry do |options|
    requires :type, type: String, values: %w[Polygon MultiPolygon]
    requires :coordinates
  end

  params :params_from_entity do |options|
    options[:entity].each{ |k, d|
      v = d.dup # Important: use dup not to modify original entity
      v[:type] = Boolean if v[:type] == 'Boolean'
      # To be homogeneous with rails and avoid timezone problems, need to use Time instead of DateTime
      if v[:type] == DateTime
        v[:type] = Time
        v[:coerce_with] = ->(val) { val.is_a?(String) ? Time.parse(val + ' UTC') : val }
      end
      if v[:values]
        classes = v[:values].map(&:class).uniq
        v[:type] = classes[0] if classes.size == 1 && v[:type] != classes[0]
      end
      v[:type] = Array[v[:type]] if v.key?(:is_array)
      send(v[:required] ? :requires : :optional, k, v.except(:required, :is_array, :param_type))
    }
  end

  ID_DESC = 'Id or the ref field value, then use "ref:[value]".'.freeze
  DATE_DESC = "Local format depends of the locale sent in http header. Default local send is english (:en)\n
  ex:\n
  en: mm-dd-yyyy\n
  fr: dd-mm-yyyy"
  EDIT_ONLY_ADMIN = 'Only available in admin.'.freeze
  MAX_DAYS = 31
end
