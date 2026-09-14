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

  def filter_tag_ids_belong_to_customer(tag_ids, customer)
    return [] if tag_ids.blank?

    customer.tags.where(ParseIdsRefs.where_clause(tag_ids)).pluck(:id)
  end

  params :request_capacity do |options|
    requires :deliverable_unit_id, type: Integer
    requires :quantity, type: Float, coerce_with: CoerceFloatString
  end

  params :request_custom_attribute do |options|
    name_opts = { type: String, regexp: /\A[^:]*\z/ }
    object_type_opts = {
      type: String,
      values: ::CustomAttribute.object_types.keys.map(&:to_s),
      documentation: { values: ::CustomAttribute.object_types.keys.map(&:to_s) }
    }
    object_class_values = (::CustomAttribute.object_classes.keys.map(&:to_s) + ['stop']).uniq
    object_class_opts = {
      type: String,
      values: object_class_values,
      documentation: { values: object_class_values },
      coerce_with: ->(value) { value == 'stop' ? 'stop_visit' : value }
    }

    if options[:required_custom_attribute_params]
      requires :name, name_opts
      requires :object_type, object_type_opts
      requires :object_class, object_class_opts
    else
      optional :name, name_opts
      optional :object_type, object_type_opts
      optional :object_class, object_class_opts
    end
    optional :default_value, types: [Array[String], String, Integer, Float, Boolean]
    optional :description, type: String
    optional :mobile_visible, type: Boolean, documentation: { desc: 'Whether the attribute is visible on mobile (visit, vehicle and route only currently).' }
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
    optional :sms_driver_template, type: String
    optional :sms_intransit_template, type: String
    optional :sms_concat, type: Boolean
    optional :enable_sms_intransit, type: Boolean

    optional :enable_external_callback, type: Boolean, documentation: { desc: 'Enable external callback' }
    optional :external_callback_url, type: String, documentation: { desc: 'External callback URL' }
    optional :external_callback_name, type: String, documentation: { desc: 'External callback name' }

    optional :enable_optimization_soft_upper_bound, type: Boolean, documentation: { desc: 'Enable overtimes' }
    optional :enable_strict_within_timewindows, type: Boolean, documentation: { desc: 'Visit duration inside the time window (whole visit between window start and end)' }
    optional :stops_preload_limit, type: Integer, documentation: { desc: 'Max stops to preload the route content when opening a plan' }
    optional :stop_max_upper_bound, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :vehicle_max_upper_bound, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }

    optional :optimization_max_split_size, type: Integer, documentation: { desc: 'Maximum number of visits to split problem', example: Planner::Application.config.optimize_max_split_size }
    optional :optimization_cluster_size, type: Integer, documentation: { desc: 'Time in seconds to group near visits', example: Planner::Application.config.optimize_cluster_size }
    optional :optimization_time, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Maximum optimization time (by vehicle)', example: Planner::Application.config.optimize_time }
    optional :optimization_minimal_time, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Minimum optimization time (by vehicle)', example: Planner::Application.config.optimize_minimal_time}
    optional :optimization_stop_soft_upper_bound, type: Float, coerce_with: CoerceFloatString, documentation: { desc: '[Obsolete] use enable_optimization_soft_upper_bound and stop_max_upper_bound instead', example: Planner::Application.config.optimize_stop_soft_upper_bound}
    optional :optimization_vehicle_soft_upper_bound, type: Float, coerce_with: CoerceFloatString, documentation: { desc: '[Obsolete] use enable_optimization_soft_upper_bound and vehicle_max_upper_bound instead', example: Planner::Application.config.optimize_vehicle_soft_upper_bound }
    optional :optimization_cost_fixed, type: Integer, documentation: { desc: 'Fixed cost for vehicles used by optimization', example: Planner::Application.config.optimize_cost_fixed }
    optional :optimization_cost_waiting_time, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Coefficient to manage waiting time', example: Planner::Application.config.optimize_cost_waiting_time }
    optional :optimization_force_start, type: Boolean, documentation: { desc: 'Force time for departure', example: Planner::Application.config.optimize_force_start }

    optional :advanced_options, type: JSON, documentation: { desc: 'Advanced options' }

    optional :devices, type: Hash, coerce_with: JSON, documentation: { desc: EDIT_ONLY_ADMIN }
  end

  params :request_deliverable_unit do |options|
    if options[:required_deliverable_unit_params]
      requires :label, type: String, documentation: { example: 'Regular parcel' }
    else
      optional :label, type: String, documentation: { example: 'Regular parcel' }
    end
    optional :ref, type: String, documentation: { example: 'RP' }
    optional :icon, type: String, documentation: { desc: "Icon name from font-awesome. Default: #{::DeliverableUnit::ICON_DEFAULT}.", example: ::DeliverableUnit::ICON_DEFAULT}
    optional :default_quantity, type: Float, documentation: { hidden: true, deprecated: true, example: '1.0', desc: 'Deprecated, use default_pickup and default_delivery.' }
    optional :default_pickup, type: Float, documentation: { example: '1.0' }
    optional :default_delivery, type: Float, documentation: { example: '2.0' }
    optional :default_capacity, type: Float, documentation: { example: '48.5' }
    optional :optimization_overload_multiplier, type: Integer
    mutually_exclusive :default_quantity, :default_pickup
    mutually_exclusive :default_quantity, :default_delivery
  end

  params :request_destination do |options|
    optional :ref, type: String, documentation: { desc: 'External unique reference. Upsert key on import (same ref updates the existing destination).', example: 'CLIENT-12' }
    optional :name, type: String, documentation: { desc: 'Display name.', example: 'Acme' }
    optional :street, type: String, documentation: { desc: 'Street and house number. Geocoded automatically when lat/lng are omitted.', example: '12 avenue Thiers' }
    optional :postalcode, type: String, documentation: { desc: 'Postal / ZIP code.', example: '33100' }
    optional :city, type: String, documentation: { desc: 'City.', example: 'Bordeaux' }
    optional :state, type: String, documentation: { desc: 'State / region.' }
    optional :country, type: String, documentation: { desc: 'Country. Falls back to customer default_country when omitted.', example: 'France' }
    optional :lat, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Latitude. Omit (or send empty with a new address) to trigger geocoding.', example: 44.8378 }
    optional :lng, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Longitude. Omit (or send empty with a new address) to trigger geocoding.', example: -0.5792 }
    optional :detail, type: String, documentation: { desc: 'Address complement (floor, intercom).' }
    optional :comment, type: String, documentation: { desc: 'Free comment shown to the driver.' }
    optional :phone_number, type: String, documentation: { desc: 'Contact phone.' }
    optional :geocoding_accuracy, type: Float, documentation: { desc: 'Geocoding confidence in 0..1. Must be inside 0..1 range.' }
    optional :geocoding_level, type: String, values: ['point', 'house', 'street', 'intersection', 'city'], documentation: { desc: 'Precision of the geocoded position.' }
    optional :tag_ids, type: Array[Integer], coerce_with: ->(value) { ParseIdsRefs.where(Tag, CoerceArrayString.parse(value)).pluck(:id) }, documentation: { desc: 'Ids or refs separated by comma. Prefix refs with "ref:" e.g. ref:promo,ref:vip', example: '1,2,ref:vip' }
    optional :duration, type: Integer, documentation: { type: 'string', desc: 'Extra service duration at the destination (HH:MM or HH:MM:SS), on top of visit duration.' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    if options[:json_import]
      optional :tags, type: Array, coerce_with: CoerceArrayString, documentation: { desc: 'Tag labels separated by comma. Created if missing on import.', example: ['tag1', 'tag2', 'tag3'] }
    end
    optional :geocoded_at,  type: Time, documentation: { type: 'string', desc: 'When coordinates were geocoded (ISO datetime).' }, coerce_with: ->(val) { val.is_a?(String) ? Time.parse(val + ' UTC') : val }
    optional :geocoder_version, type: String, documentation: { desc: 'Geocoder version that produced the current coordinates.' }
    optional :visits, type: Array, documentation: { param_type: 'body', desc: 'Nested visits. Omit id to create; send id or ref to update.' } do
      if options[:skip_visit_id].nil?
        optional :id, type: Integer, documentation: { desc: 'Required to retrieve an existing visit, if left blank a new visit will be created', hidden: options[:skip_visit_id] }
      end
      use(:request_visit, options)
    end
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

  params :request_route do |options|
    optional :force_start, type: Boolean, documentation: { desc: 'DEPRECATED. Configure force start on the vehicle usage set instead.' }
    optional :ref, type: String, documentation: { desc: 'External reference of the route.', example: 'VEH-1' }
    optional :hidden, type: Boolean, documentation: { desc: 'When true the route is hidden on the map.' }
    optional :locked, type: Boolean, documentation: { desc: 'When true, optimization does not change this route.' }
    optional :color, type: String, documentation: { desc: "Color code with #. Default: #{Planner::Application.config.destination_color_default}.", example: '#FF0000' }
    optional :departure, type: Integer, documentation: { type: 'string', desc: 'Forced departure time from the start store (HH:MM).' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
  end

  params :request_store do |options|
    optional :ref, type: String, documentation: { desc: 'External unique reference. Upsert key on import.', example: 'DEPOT-NORD' }
    if options[:require_store_name]
      requires :name, type: String, documentation: { desc: 'Display name.', example: 'North depot' }
    else
      optional :name, type: String, documentation: { desc: 'Display name.', example: 'North depot' }
    end
    optional :street, type: String, documentation: { desc: 'Street and house number. Geocoded automatically when lat/lng are omitted.' }
    optional :postalcode, type: String
    optional :city, type: String
    optional :state, type: String
    optional :country, type: String, documentation: { desc: 'Country. Falls back to customer default_country when omitted.' }
    optional :lat, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Latitude. Omit (or send empty with a new address) to trigger geocoding.' }
    optional :lng, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Longitude. Omit (or send empty with a new address) to trigger geocoding.' }
    optional :color, type: String, documentation: { desc: "Color code with #. Default: #{Planner::Application.config.store_color_default}." }
    optional :icon, type: String, documentation: { desc: "Icon name from font-awesome. Default: #{Planner::Application.config.store_icon_default}." }
    optional :icon_size, type: String, values: MapIconSize::SIZES, documentation: { desc: "Icon size. Default depends on entity type (destination, store)." }
    optional :store_reloads, type: Array, documentation: { param_type: 'body' } do
      use :request_store_reload
    end
  end

  params :request_store_reload do |options|
    optional :id, type: Integer, documentation: { desc: 'Existing store reload id. Omit to create.' }
    optional :ref, type: String, documentation: { desc: 'External unique reference. Upsert key on import.', example: 'RELOAD-1' }
    optional :duration, type: Integer, documentation: { type: 'string', desc: 'Service duration at the reload (HH:MM or HH:MM:SS).' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :time_window_start, type: Integer, documentation: { type: 'string', desc: 'Reload time window start (HH:MM).' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :time_window_end, type: Integer, documentation: { type: 'string', desc: 'Reload time window end (HH:MM).' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
  end

  params :request_user do |options|
    if options[:create]
      requires :email, type: String
      requires :customer_id, type: Integer
      requires :layer_id, type: Integer
    else
      optional :email, type: String
      optional :customer_id, type: Integer
      optional :layer_id, type: Integer
    end
    optional :password, type: String
    optional :role_id, type: Integer, documentation: { desc: 'Only available in admin. Defaults to the reseller default role when omitted on create.' }
    optional :ref, type: String, documentation: { desc: 'Only available in admin.' }
    optional :api_key, type: String
    optional :url_click2call, type: String
    optional :prefered_unit, type: String
    optional :locale, type: String
    optional :time_zone, type: String, values: ActiveSupport::TimeZone.all.map(&:name)
    optional :default_display_polylines, type: Boolean
  end

  params :request_vehicle do |options|
    optional :ref, type: String, documentation: { desc: 'External unique reference. Use ref:VALUE in path/ids filters.', example: 'VEH-1' }
    optional :name, type: String, documentation: { desc: 'Display name.', example: 'Truck 1' }
    optional :contact_email, type: String, documentation: { desc: 'Driver\'s device E-Mail. Several emails might be transmitted separated by spaces, commas or semicolons.' }
    optional :phone_number, type: String
    optional :emission, type: Float, coerce_with: CoerceFloatString
    optional :consumption, type: Float, coerce_with: CoerceFloatString
    optional :capacity, type: Integer, documentation: { hidden: true, deprecated: true, desc: 'Deprecated, use capacities instead.'}
    optional :capacity_unit, type: String, documentation: { hidden: true, deprecated: true, desc: 'Deprecated, use capacities and deliverable_unit entity instead.'}
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
    optional :speed_multiplicator, type: Float, coerce_with: CoerceFloatString, documentation: { hidden: true, deprecated: true, desc: 'Deprecated, use speed_multiplier instead.' }
    optional :speed_multiplier, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Speed multiplier applied to router times (1 is default).', example: 1.0 }
    optional :max_distance, type: Integer, documentation: { desc: 'Maximum achievable distance in meters' }
    optional :max_ride_distance, type: Integer, documentation: { desc: 'Maximum riding distance between two stops within a route in meters' }
    optional :max_ride_duration, type: Integer, documentation: { desc: 'Maximum riding time between two stops within a route (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :tag_ids, type: Array[Integer], coerce_with: ->(value) { ParseIdsRefs.where(Tag, CoerceArrayString.parse(value)).pluck(:id) }, documentation: { desc: 'Ids or refs separated by comma. Prefix refs with "ref:" e.g. ref:promo,ref:vip', param_type: 'form', example: '1,2,ref:vip' }
    optional :devices, type: Hash, documentation: { desc: 'Telematics device identifiers keyed by provider.' }
    optional :custom_attributes, type: Hash, documentation: { desc: 'Additional typed properties defined on CustomAttribute for vehicles.' }
  end

  params :request_vehicle_usage do |options|
    optional :time_window_start, type: Integer, documentation: { type: 'string', desc: 'Shift start (HH:MM). Falls back to the set default when unset.' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :time_window_end, type: Integer, documentation: { type: 'string', desc: 'Shift end (HH:MM). Falls back to the set default when unset.' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :service_time_start, type: Integer, documentation: { type: 'string', desc: 'Service time at the start store (HH:MM).' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :service_time_end, type: Integer, documentation: { type: 'string', desc: 'Service time at the stop store (HH:MM).' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :work_time, type: Integer, documentation: { type: 'string', desc: 'Maximum working duration (HH:MM).' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :max_distance, type: Integer, documentation: { type: 'integer', desc: 'Maximum achievable distance in meters' }
    optional :max_reload, type: Integer, documentation: { type: 'integer', desc: 'Maximum number of reloads per route' }
    optional :rest_start, type: Integer, documentation: { type: 'string', desc: 'Earliest rest start (HH:MM).' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :rest_stop, type: Integer, documentation: { type: 'string', desc: 'Latest rest end (HH:MM).' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :rest_duration, type: Integer, documentation: { type: 'string', desc: 'Rest duration (HH:MM).' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :visit_duration_coef, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Coefficient applied to visit durations for this vehicle usage (falls back to vehicle usage set, then 1)' }
    optional :destination_duration_coef, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Coefficient applied to destination durations for this vehicle usage (falls back to vehicle usage set, then 1)' }
    optional :tag_ids, type: Array[Integer], coerce_with: ->(value) { ParseIdsRefs.where(Tag, CoerceArrayString.parse(value)).pluck(:id) }, documentation: { desc: 'Ids or refs separated by comma. Prefix refs with "ref:" e.g. ref:promo,ref:vip', param_type: 'form', example: '1,2,ref:vip' }

    optional :store_start_id, type: Integer, documentation: { type: Integer, desc: 'Start depot store id. Falls back to the set default.' }
    optional :store_stop_id, type: Integer, documentation: { type: Integer, desc: 'End depot store id. Falls back to the set default.' }
    optional :store_reload_ids, type: Array[Integer], coerce_with: ->(value) { ParseIdsRefs.where_pluck_ids(StoreReload, CoerceArrayString.parse(value)) }, documentation: { desc: 'Ids or refs separated by comma. Prefix refs with "ref:" e.g. ref:promo,ref:vip', example: '1,2,ref:vip' }

    # Deprecated fields
    optional :open, type: Integer, documentation: { hidden: true, type: 'string', desc: '[Deprecated] Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    mutually_exclusive :time_window_start, :open
    optional :close, type: Integer, documentation: { hidden: true, type: 'string', desc: '[Deprecated] Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    mutually_exclusive :time_window_end, :close
  end

  params :request_vehicle_usage_set do |options|
    optional :name, type: String, documentation: { type: String, desc: 'Display name of the context (Morning, Evening, …).', example: 'Default' }
    optional :time_window_start, type: Integer, documentation: { type: 'string', desc: 'Default shift start (HH:MM) inherited by vehicle usages.' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :time_window_end, type: Integer, documentation: { type: 'string', desc: 'Default shift end (HH:MM) inherited by vehicle usages.' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :store_start_id, type: Integer, documentation: { type: Integer, desc: 'Default start depot store id.' }
    optional :store_stop_id, type: Integer, documentation: { type: Integer, desc: 'Default end depot store id.' }
    optional :store_reload_ids, type: Array[Integer], coerce_with: ->(value) { ParseIdsRefs.where_pluck_ids(StoreReload, CoerceArrayString.parse(value)) }, documentation: { desc: 'Ids or refs separated by comma. Prefix refs with "ref:" e.g. ref:promo,ref:vip', example: '1,2,ref:vip' }
    optional :service_time_start, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :service_time_end, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :work_time, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :rest_start, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :rest_stop, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :rest_duration, type: Integer, documentation: { type: 'string', desc: 'Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :store_rest_id, type: Integer, documentation: { type: Integer }
    optional :max_distance, type: Integer, documentation: { type: Integer, desc: 'Maximum achievable distance in meters' }
    optional :max_reload, type: Integer, documentation: { type: Integer, desc: 'Maximum number of reloads per route' }
    optional :max_ride_distance, type: Integer, documentation: { type: Integer, desc: 'Maximum riding distance between two stops within a route in meters' }
    optional :max_ride_duration, type: Integer, documentation: { type: 'string', desc: 'Maximum riding time between two stops within a route (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :visit_duration_coef, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Default coefficient applied to visit durations for vehicle usages in this set (default: 1)' }
    optional :destination_duration_coef, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Default coefficient applied to destination durations for vehicle usages in this set (default: 1)' }
    # Deprecated fields
    optional :open, type: Integer, documentation: { hidden: true, type: 'string', desc: 'Deprecated, use `visit_duration` instead' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :close, type: Integer, documentation: { hidden: true, type: 'string', desc: 'Deprecated, use `time_window_end` instead.' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
  end

  params :request_visit do |options|
    optional :tag_ids, type: Array[Integer], coerce_with: ->(value) { ParseIdsRefs.where(Tag, CoerceArrayString.parse(value)).pluck(:id) }, documentation: { desc: 'Ids or refs separated by comma. Prefix refs with "ref:" e.g. ref:promo,ref:vip', example: '1,2,ref:vip' }
    if options[:json_import]
      optional :tags, type: Array, coerce_with: CoerceArrayString, documentation: { desc: 'Tag labels separated by comma.', example: ['tag1', 'tag2', 'tag3'] }
    end

    optional :ref, type: String, documentation: { desc: 'External reference unique among visits of the related destination. Upsert key on import.', example: 'V1' }

    optional :quantities, type: Array, documentation: { param_type: 'body', desc: 'Pickup/delivery quantities per deliverable unit. Prefer pickup and delivery over deprecated quantity.' } do
      optional :deliverable_unit_id, type: Integer, documentation: { desc: 'Deliverable unit id. Required unless deliverable_unit_label is sent on JSON import.', example: 1 }
      if options[:json_import]
        optional :deliverable_unit_label, type: String, documentation: { desc: 'Deliverable unit label, used on JSON import when id is unknown.' }
      end
      optional :pickup, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Quantity picked up at the visit.', example: 0.0 }
      optional :delivery, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Quantity delivered at the visit.', example: 1.0 }
      optional :quantity, type: Float, coerce_with: CoerceFloatString, documentation: { hidden: true, deprecated: true, desc: 'Deprecated, use pickup and delivery instead.' }
      mutually_exclusive :quantity, :delivery
      mutually_exclusive :quantity, :pickup
      at_least_one_of :pickup, :delivery, :quantity
      at_least_one_of :deliverable_unit_id, :deliverable_unit_label
    end
    optional :quantity, type: Integer, documentation: { desc: 'Deprecated, use quantities instead.', hidden: true }
    optional :quantity1_1, type: Integer, documentation: { desc: 'Deprecated, use quantities instead.', hidden: true }
    optional :quantity1_2, type: Integer, documentation: { desc: 'Deprecated, use quantities instead.', hidden: true }

    optional :time_window_start_1, type: Integer, documentation: { type: 'string', desc: 'Start of the first time window (HH:MM or HH:MM:SS).', example: '08:00' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :open1, type: Integer, documentation: { hidden: true, type: 'string', desc: '[Deprecated] Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    mutually_exclusive :time_window_start_1, :open1

    optional :time_window_end_1, type: Integer, documentation: { type: 'string', desc: 'End of the first time window (HH:MM or HH:MM:SS).', example: '12:00' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :close1, type: Integer, documentation: { hidden: true, type: 'string', desc: '[Deprecated] Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    mutually_exclusive :time_window_end_1, :close1

    optional :duration, type: Integer, documentation: { type: 'string', desc: 'Visit service duration (HH:MM or HH:MM:SS). Falls back to customer visit_duration when omitted.', example: '00:10:00' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :time_window_start_2, type: Integer, documentation: { type: 'string', desc: 'Start of the optional second time window (HH:MM or HH:MM:SS).' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :open2, type: Integer, documentation: { hidden: true, type: 'string', desc: '[Deprecated] Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    mutually_exclusive :time_window_start_2, :open2

    optional :time_window_end_2, type: Integer, documentation: { type: 'string', desc: 'End of the optional second time window (HH:MM or HH:MM:SS).' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    optional :close2, type: Integer, documentation: { hidden: true, type: 'string', desc: '[Deprecated] Schedule time (HH:MM)' }, coerce_with: ->(value) { ScheduleType.new.cast(value) }
    mutually_exclusive :time_window_end_2, :close2

    optional :force_position, type: String, values: %w[neutral always_first never_first always_final], documentation: { type: 'string', desc: 'Forced position among visits that share the same constraint on the route: always_first, never_first, always_final, or neutral (default).', example: 'neutral' }
    optional :custom_attributes, type: Hash, documentation: { desc: 'Additional typed properties defined on CustomAttribute for visits.' }
    optional :revenue, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Revenue generated by performing the visit' }

    # Route params related to JSON import
    if options[:json_import]
      optional :ref_vehicle, type: String, documentation: { desc: 'Vehicle ref. If set (or route is set), a planning is created and the visit is assigned to that vehicle route.' }
      optional :route, type: String, documentation: { desc: 'Route ref. If set (or ref_vehicle is set), a planning is created and the visit is assigned to that route.' }
      optional :active, type: Boolean, documentation: { desc: 'Whether the created stop is active on the planning route. Defaults to true.' }
      optional :stop_custom_attributes, type: Hash, documentation: { desc: 'Custom attributes stored on the created stop (not the visit).' }
    end
  end

  params :request_zone do |options|
    optional :name, type: String, documentation: { desc: 'Display name.', example: 'North sector' }
    optional :vehicle_id, type: Integer, documentation: { desc: 'Vehicle this zone is assigned to. Applying the zoning sends stops inside the polygon to that vehicle route.' }
    optional :polygon, type: JSON, documentation: { desc: 'GeoJSON Feature (Polygon or MultiPolygon).' } do use :request_feature end
    optional :speed_multiplier, type: Float, coerce_with: CoerceFloatString, documentation: { desc: 'Speed multiplier for this area (1 is default).' }
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
      # hidden/deprecated are swagger-entity keys, not Grape validators
      send(v[:required] ? :requires : :optional, k, v.except(:required, :is_array, :param_type, :hidden, :deprecated))
    }
  end

  params :optional_pagination do
    optional :page, type: Integer, values: ->(v) { v.nil? || v >= 1 }, desc: '1-based page. When set, wrap the list as { items, page, per_page, total }. Without page, returns a bare array.'
    optional :per_page, type: Integer, default: 100, values: 1..500, desc: 'Page size when page is set. Default 100, max 500.'
  end

  def paginate_collection(collection, page:, per_page:)
    if collection.respond_to?(:offset)
      total = collection.except(:includes).count
      items = collection.offset((page - 1) * per_page).limit(per_page).load
    else
      total = collection.size
      items = collection.slice((page - 1) * per_page, per_page) || []
    end
    [items, total]
  end

  def present_paginated(collection, entity)
    if params[:page]
      items, total = paginate_collection(collection, page: params[:page], per_page: params[:per_page])
      {
        items: entity.represent(items, serializable: true),
        page: params[:page],
        per_page: params[:per_page],
        total: total
      }
    else
      collection = collection.load if collection.respond_to?(:load)
      present collection, with: entity
    end
  end

  ID_DESC = 'Numeric id or external reference prefixed with "ref:". Examples: 42 or ref:CLIENT-12. References must not contain commas.'.freeze
  DATE_DESC = "Local format depends of the locale sent in http header. Default local send is english (:en)\n
  ex:\n
  en: mm-dd-yyyy\n
  fr: dd-mm-yyyy"
  EDIT_ONLY_ADMIN = 'Only available in admin.'.freeze
  MAX_DAYS = 31
end
