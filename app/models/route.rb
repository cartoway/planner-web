# Copyright © Mapotempo, 2013-2017
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

require 'simplify_geojson_tracks_job'

class Route < ApplicationRecord
  RELATION_ORDER_KEYS = %i[pickup_delivery order sequence]

  attr_accessor :migration_skip

  belongs_to :planning, touch: true
  belongs_to :vehicle_usage, optional: true
  has_many :stops, inverse_of: :route, autosave: true, dependent: :delete_all, after_add: :update_stops_track, after_remove: :update_stops_track

  include QuantityAttr
  quantity_attr :pickups, :deliveries

  nilify_blanks
  validates :planning, presence: true
  #  validates :vehicle_usage, presence: true # nil on unplanned route
  validate :stop_index_validation
  attr_accessor :no_stop_index_validation, :vehicle_color_changed

  include TimeAttr
  attribute :start, ScheduleType.new
  attribute :end, ScheduleType.new
  attribute :departure, ScheduleType.new
  time_attr :start, :end, :departure

  before_update :update_vehicle_usage, :update_geojson, unless: :migration_skip

  after_initialize :assign_defaults, if: -> { new_record? }
  after_create :complete_geojson
  after_save { @computed = false }

  before_save :outdated_if_changed

  after_save :invalidate_route_cache, :invalidate_planning_cache
  after_destroy :invalidate_route_cache, :invalidate_planning_cache

  scope :available, -> { where("vehicle_usage_id IS NULL OR NOT (COALESCE(locked, false) AND COALESCE(hidden, false))") }
  scope :available_or_outdated, -> { where("vehicle_usage_id IS NULL OR NOT (COALESCE(locked, false) AND COALESCE(hidden, false))") }
  scope :for_customer_id, ->(customer_id) { joins(:planning).where(plannings: {customer_id: customer_id}) }
  scope :includes_vehicle_usages, -> {
    includes(vehicle_usage: [
      :store_start, :store_stop, :store_rest, :tags,
      vehicle_usage_set: [:store_start, :store_stop, :store_rest],
      vehicle: [:router, :tags, {customer: :router}]
    ])
  }
  scope :includes_stops, -> { includes(:stops) }
  # The second visit is for counting the visit index from all the visits of the destination
  scope :includes_destinations_and_stores, -> {
    includes(
      stops: [
        {
          visit: [
            :relation_currents,
            :relation_successors,
            :tags,
            destination: [
              :tags,
              :visits,
              { customer: :deliverable_units }
            ]
          ]
        },
        {
          store: [
            :customer
          ]
        }
      ]
    )
  }
  scope :includes_deliverable_units, -> { includes(vehicle_usage: [:vehicle_usage_set, vehicle: [customer: :deliverable_units]]) }
  scope :stop_visits, -> { includes(:stops).where(type: StopVisit.name) }

  include RefSanitizer

  amoeba do
    enable

    customize(lambda { |original, copy|
      def copy.update_vehicle_usage; end

      def copy.assign_defaults; end

      copy.planning = original.planning
      copy.stops.each{ |stop|
        stop.route = copy
      }
    })
  end

  def outdated_if_changed
    return if !(will_save_change_to_departure? ||
                will_save_change_to_force_start?)
    self.outdated = true
  end

  def init_stops(compute = true, ignore_errors = false)
    stops.clear
    if vehicle_usage? && vehicle_usage.default_rest_duration
      stops.build(type: StopRest.name, active: true, index: 1)
    end

    compute!(ignore_errors: ignore_errors) if compute
  end

  def default_stops
    i = stops_size
    planning.visits_compatibles.each { |visit|
      stops.build(type: StopVisit.name, visit: visit, active: true, index: i += 1)
    }
    self.outdated = true
  end

  def service_time_start_value
    vehicle_usage.default_service_time_start if vehicle_usage? && vehicle_usage.default_service_time_start&.positive?
  end

  def service_time_end_value
    vehicle_usage.default_service_time_end if vehicle_usage? && vehicle_usage.default_service_time_end&.positive?
  end

  def work_time_value
    vehicle_usage.default_work_time if vehicle_usage? && vehicle_usage.default_work_time
  end

  def init_route_data
    {
      stop_distance: 0,
      stop_no_path: false,
      stop_out_of_drive_time: nil,
      stop_out_of_work_time: nil,
      out_of_max_ride_distance: nil,
      out_of_max_ride_duration: nil,
      emission: nil,
      start: nil,
      end: nil,
      distance: 0,
      drive_time: nil,
      wait_time: nil,
      visits_duration: nil,
      pickups: nil,
      deliveries: nil,
      revenue: nil,
      cost_distance: nil,
      cost_fixed: nil,
      cost_time: nil
    }
  end

  def is_expired?
    return false if planning.date.nil? || stops.only_active_stop_visits.empty? || stops.only_active_stop_visits.last.time.nil?

    planning.date + stops.only_active_stop_visits.last.time.seconds + 12.hour < DateTime.now
  end

  def store_traces(geojson_tracks_store, trace, options = {})
    if trace && !options[:no_geojson]
      geojson_tracks_store << {
        type: 'Feature',
        geometry: {
          type: 'LineString',
          polylines: trace,
        },
        properties: {
          route_id: self.id,
          color: self.default_color,
          drive_time: options[:drive_time],
          distance: options[:distance]
        }.compact
      }.to_json
    end
  end

  def plan(departure = nil, options = {})
    options[:ignore_errors] = false if options[:ignore_errors].nil?

    geojson_tracks_store = []

    route_attributes = init_route_data

    if vehicle_usage?
      service_time_start = service_time_start_value
      service_time_end = service_time_end_value
      route_attributes[:end] = route_attributes[:start] = departure || vehicle_usage.default_time_window_start
      speed_multiplier = vehicle_usage.vehicle.default_speed_multiplier
      router = vehicle_usage.vehicle.default_router
      router_dimension = vehicle_usage.vehicle.default_router_dimension
      stops_drive_time = {}

      max_distance = vehicle_usage.vehicle.max_distance || planning.vehicle_usage_set.max_distance
      max_ride_distance = vehicle_usage.vehicle.max_ride_distance || planning.vehicle_usage_set.max_ride_distance
      max_ride_duration = vehicle_usage.vehicle.max_ride_duration || planning.vehicle_usage_set.max_ride_duration

      # Add service time
      unless service_time_start.nil?
        route_attributes[:end] += service_time_start
      end

      # default scope is sorted by index but in case of a move preloaded order might be invalid
      stops_sort = stops.sort_by(&:index)

      # Collect route legs
      segments = collect_segments_for_routing(stops_sort)

      # Use pre-computed traces if available, otherwise compute them
      traces = @traces.dup || process_traces(segments, router, router_dimension, speed_multiplier, departure, options = {})
      traces[0] = [0, 0, nil] unless vehicle_usage.default_store_start&.position?

      # Recompute Stops
      stops_time_windows = {}
      previous_with_pos = vehicle_usage.default_store_start&.position?
      stops_sort.each{ |stop|
        stop_attributes = {}
        if stop.active && (stop.position? || (stop.is_a?(StopRest) && ((stop.time_window_start_1 && stop.time_window_end_1) || (stop.time_window_start_2 && stop.time_window_end_2)) && stop.duration))
          stop_attributes[:distance], stop_attributes[:drive_time], trace = traces.shift
          stop_attributes[:no_path] = previous_with_pos && stop.position? && trace.nil?

          store_traces(geojson_tracks_store, trace, options.merge(drive_time: stop_attributes[:drive_time], distance: stop_attributes[:distance]))

          if stop_attributes[:drive_time]
            stops_drive_time[stop] = stop_attributes[:drive_time]
            stop_attributes[:time] = route_attributes[:end] + stop_attributes[:drive_time]
            route_attributes[:drive_time] = (route_attributes[:drive_time] || 0) + stop_attributes[:drive_time]
          elsif !stop_attributes[:no_path]
            stop_attributes[:time] = route_attributes[:end]
          else
            stop_attributes[:time] = nil
          end

          if stop_attributes[:time]
            open, close, late_wait = stop.best_open_close(stop_attributes[:time])
            stops_time_windows[stop] = [open, close]
            if open && stop_attributes[:time] < open
              stop_attributes[:wait_time] = open - stop_attributes[:time]
              stop_attributes[:time] = open
              route_attributes[:wait_time] = (route_attributes[:wait_time] || 0) + stop_attributes[:wait_time]
            else
              stop_attributes[:wait_time] = nil
            end
            stop_attributes[:out_of_window] = !!(late_wait && late_wait > 0)
            route_attributes[:revenue] = route_attributes[:revenue].nil? ? stop.visit&.revenue : route_attributes[:revenue] + (stop.visit&.revenue || 0)
            route_attributes[:distance] += stop_attributes[:distance] if stop_attributes[:distance]
            route_attributes[:end] = stop_attributes[:time] + stop.duration
            route_attributes[:end] += stop.destination_duration if !stop.is_a?(StopRest) && previous_with_pos.is_a?(Stop) && stop.position != previous_with_pos.position
            route_attributes[:visits_duration] = (route_attributes[:visits_duration] || 0) + stop.duration if !stop.is_a?(StopRest)
            route_attributes[:visits_duration] += stop.destination_duration if !stop.is_a?(StopRest) && previous_with_pos.is_a?(Stop) && stop.position != previous_with_pos.position
            stop_attributes[:out_of_drive_time] = stop_attributes[:time] > vehicle_usage.default_time_window_end
            stop_attributes[:out_of_work_time] = vehicle_usage.outside_default_work_time?(route_attributes[:start], stop_attributes[:time])
            stop_attributes[:out_of_max_distance] = max_distance && (route_attributes[:distance] > max_distance)
            if previous_with_pos&.is_a? Stop
              # max_ride only apply between stops (stores excluded)
              stop_attributes[:out_of_max_ride_distance] = max_ride_distance && stop_attributes[:distance] && (stop_attributes[:distance] > max_ride_distance)
              stop_attributes[:out_of_max_ride_duration] = max_ride_duration && (stop_attributes[:drive_time] > max_ride_duration)
              route_attributes[:out_of_max_ride_distance] ||= stop_attributes[:out_of_max_ride_distance]
              route_attributes[:out_of_max_ride_duration] ||= stop_attributes[:out_of_max_ride_duration]
            else
              stop_attributes[:out_of_max_ride_distance] = stop_attributes[:out_of_max_ride_duration] = false
            end
          end
          previous_with_pos = stop if stop.position?
        else
          stop_attributes[:active] = stop_attributes[:out_of_capacity] = stop_attributes[:out_of_drive_time] = stop_attributes[:out_of_window] = stop_attributes[:no_path] = stop_attributes[:out_of_work_time] =
            stop_attributes[:out_of_max_distance] = stop_attributes[:out_of_max_ride_distance] = stop_attributes[:out_of_max_ride_duration] = false
          stop_attributes[:distance] = stop_attributes[:time] = stop_attributes[:wait_time] = nil
        end
        stop.attributes = stop_attributes
      }

      unless options[:no_quantities]
        _stop_load_hash, route_attributes[:pickups], route_attributes[:deliveries] = compute_loads(stops_sort)
      end
      # Last stop to store
      distance, drive_time, trace = traces.shift
      if drive_time
        route_attributes[:distance] += distance
        stops_drive_time[:stop] = drive_time
        route_attributes[:end] += drive_time
        route_attributes[:stop_distance], route_attributes[:stop_drive_time] = distance, drive_time
        route_attributes[:drive_time] += drive_time if route_attributes[:drive_time]
        route_attributes[:cost_distance] = route_attributes[:distance].to_f / 1000 * vehicle_usage.default_cost_distance if vehicle_usage.default_cost_distance
        route_attributes[:cost_fixed] = vehicle_usage.default_cost_fixed if vehicle_usage.default_cost_fixed
        route_attributes[:cost_time] = (route_attributes[:end] - route_attributes[:start]).to_f / 3600 * vehicle_usage.default_cost_time if vehicle_usage.default_cost_time
      end
      route_attributes[:stop_no_path] = vehicle_usage.default_store_stop&.position? && stops_sort.any?{ |s| s.active && s.position? } && trace.nil?

      # Add service time to end point
      route_attributes[:end] += service_time_end unless service_time_end.nil?

      store_traces(geojson_tracks_store, trace, options.merge(drive_time: drive_time, distance: stop_distance))
      route_attributes[:geojson_tracks] = geojson_tracks_store unless options[:no_geojson]

      route_attributes[:stop_out_of_drive_time] = route_attributes[:end] > vehicle_usage.default_time_window_end
      route_attributes[:stop_out_of_work_time] = vehicle_usage.outside_default_work_time?(route_attributes[:start], route_attributes[:end])
      max_distance = vehicle_usage.vehicle.max_distance || planning.vehicle_usage_set.max_distance
      route_attributes[:stop_out_of_max_distance] = max_distance ? route_attributes[:distance] > max_distance : false
      route_attributes[:emission] = (vehicle_usage.vehicle.emission.nil? || vehicle_usage.vehicle.consumption.nil?) ? nil : (route_attributes[:distance] / 1000 * vehicle_usage.vehicle.emission * vehicle_usage.vehicle.consumption / 100)

      self.assign_attributes(route_attributes)
      [stops_sort, stops_drive_time, stops_time_windows]
    end
  end

  # Available options:
  # ignore_errors
  # no_geojson
  # no_quantities
  def compute!(options = {})
    if self.vehicle_usage?
      self.geojson_tracks = nil
      previous_position_hash = {}
      stops_sort, stops_drive_time, stops_time_windows = plan(
        # Hack to allow manual set of self.start from the API and keep the value
        # when used in conjunction with self.force_start
        self.departure || (self.force_start ? self.start : vehicle_usage.default_time_window_start),
        options
      )

      if stops_sort
        previous_position = nil
        stops_sort.each{ |stop|
          next if stop.is_a?(StopRest) || !stop.active?

          previous_position_hash[stop.id] = previous_position
          previous_position = stop.position if stop.position?
        }
        compute_out_of_force_position
        compute_out_of_relations
        compute_out_of_skill

        # Try to minimize waiting time by a later begin
        time = self.end
        time -= stops_drive_time[:stop] if stops_drive_time[:stop]
        time -= vehicle_usage.default_service_time_end if vehicle_usage.default_service_time_end
        stops_sort.reverse_each{ |stop|
          if stop.active && (stop.position? || stop.is_a?(StopRest))
            _open, close = stops_time_windows[stop]
            stop_total_duration = stop.duration
            stop_total_duration += stop.destination_duration if stop.is_a?(StopVisit) && (!previous_position_hash.key?(stop.id) || stop.position != previous_position_hash[stop.id])
            if stop.time && (stop.out_of_window || (close && time > close))
              time = [stop.time, close ? close - stop_total_duration  : 0].max
            else
              # Latest departure time
              time = [time, close].min if close

              # New arrival stop time
              time -= stop_total_duration
            end

            # Previous departure time
            time -= stops_drive_time[stop] if stops_drive_time[stop]
          end
        }

        time -= vehicle_usage.default_service_time_start if vehicle_usage.default_service_time_start

        force_start = !self.force_start.nil? ? self.force_start : planning.customer.optimization_force_start.nil? ? Planner::Application.config.optimize_force_start : planning.customer.optimization_force_start
        if self.departure.nil? && time > start && !force_start
          # We can sleep a bit more on morning, shift departure
          plan(time, options)
        end
      end
    else
      _load_stop_hash, self.pickups, self.deliveries = compute_loads unless options[:no_quantities]
    end

    self.geojson_points = stops_to_geojson_points unless options[:no_geojson]

    self.outdated = false
    @computed = true
    true
  end

  def collect_segments_for_routing(stops_sort)
    segments = []
    last_lat, last_lng = nil, nil

    if vehicle_usage?
      if vehicle_usage.default_store_stop&.position?
        last_lat, last_lng = vehicle_usage.default_store_stop.lat, vehicle_usage.default_store_stop.lng
      end
      segments = stops_sort.select{ |stop|
        stop.active && (stop.position? || (stop.is_a?(StopRest) && ((stop.time_window_start_1 && stop.time_window_end_1) || (stop.time_window_start_2 && stop.time_window_end_2)) && stop.duration))
      }.reverse.collect{ |stop|
        if stop.position?
          ret = [stop.lat, stop.lng, last_lat, last_lng] if !last_lat.nil? && !last_lng.nil?
          last_lat, last_lng = stop.lat, stop.lng
        elsif stop.is_a?(StopRest)
          ret = [last_lat, last_lng, last_lat, last_lng] if !last_lat.nil? && !last_lng.nil?
        end
        ret
      }.reverse

      if !last_lat.nil? && !last_lng.nil? && vehicle_usage.default_store_start&.position?
        segments.insert(0, [vehicle_usage.default_store_start.lat, vehicle_usage.default_store_start.lng, last_lat, last_lng])
      else
        segments.insert(0, nil)
      end
    end

    segments
  end

  def process_traces(segments, router, router_dimension, speed_multiplier, departure, options = {})
    begin
      router_options = vehicle_usage.vehicle.default_router_options.symbolize_keys
      router_options[:geometry] = false if options[:no_geojson]
      router_options[:speed_multiplier] = speed_multiplier
      router_options[:speed_multiplier_areas] = Zoning.speed_multiplier_areas(planning.zonings)
      # Use Time.zone.parse to preserve time zone from user (instead of to_time)
      router_options[:departure] = Time.zone.parse((planning.date || Date.today).to_s) + departure if departure

      ts = router.trace_batch(segments.reject(&:nil?), router_dimension, router_options)
      traces = segments.map{ |segment|
        next [nil, nil, nil] if segment.nil?

        (ts && !ts.empty? && ts.shift) || [nil, nil, nil]
      }
      store_precomputed_traces(traces, options)
      traces.dup
    rescue RouterError
      raise unless options[:ignore_errors]
      [nil, nil, nil] * segments.size
    end
  end

  def store_precomputed_traces(traces, options = {})
    return if traces.blank?

    @traces = traces
  end

  def reset_traces!
    @traces = nil
  end

  def compute(options = {})
    compute!(options) if self.outdated
    true
  end

  def compute_saved(options = {})
    compute_saved!(options) if self.outdated
    true
  end

  def compute_saved!(options = {})
    compute!(options)

    group_stop_visits = stops.select{ |s| s.is_a?(StopVisit) }.map(&:import_attributes)
    group_stop_rests = stops.select{ |s| s.is_a?(StopRest) }.map(&:import_attributes)
    group_stop_stores = stops.select{ |s| s.is_a?(StopStore) }.map(&:import_attributes)

    StopVisit.import(group_stop_visits, validate_with_context: :update, raise_error: true, on_duplicate_key_update: {conflict_target: [:id], columns: :all})
    StopRest.import(group_stop_rests, validate_with_context: :update, raise_error: true, on_duplicate_key_update: {conflict_target: [:id], columns: :all})
    StopStore.import(group_stop_stores, validate_with_context: :update, raise_error: true, on_duplicate_key_update: {conflict_target: [:id], columns: :all})
    complete_geojson
    # Indirectly save route to avoid Stops callbacks
    self.update_columns(self.import_attributes)
    invalidate_route_cache
    invalidate_planning_cache

    if Planner::Application.config.delayed_job_use
      Delayed::Job.enqueue(SimplifyGeojsonTracksJob.new(self.planning.customer_id, self.id))
    end
    true
  end

  def set_visits(visits, recompute = true, ignore_errors = false)
    Stop.transaction do
      init_stops false
      add_visits visits, recompute, ignore_errors
    end
  end

  def set_objects(objects, recompute = true, ignore_errors = false)
    Stop.transaction do
      init_stops false
      add_objects objects, recompute, ignore_errors
    end
  end

  def add_objects(objects, recompute = true, ignore_errors = false)
    Stop.transaction do
      i = stops.size
      collected_stops = objects.map.with_index{ |stop, index|
        object, active = stop

        if object.is_a?(Visit) && planning.tags_compatible?(object.tags.to_a | object.destination.tags.to_a)
          stops.new(type: StopVisit.name, visit: object, active: active, index: i += 1)
        elsif object.is_a?(Store)
          # Do not consider store start and store stop
          next if index == 0 && object == vehicle_usage.default_store_start || index == objects.size - 1 && object == vehicle_usage.default_store_stop

          stops.new(type: StopStore.name, store: object, index: i += 1)
        end
      }.compact
      Stop.import(collected_stops)
      self.outdated = true

      compute(ignore_errors: ignore_errors) if recompute
    end
  end

  def add_visits(visits, recompute = true, ignore_errors = false)
    Stop.transaction do
      i = stops.size
      collected_stops = visits.map{ |stop|
        visit, active = stop
        stops.new(type: StopVisit.name, visit: visit, active: active, index: i += 1)
      }
      Stop.import(collected_stops)
      self.outdated = true

      compute(ignore_errors: ignore_errors) if recompute
    end
  end

  def add_store(store, index = nil, active = true, stop_id = nil)
    raise I18n.t('activerecord.errors.models.route.attributes.stops.store.must_be_associated_to_vehicle_usage') if self.vehicle_usage.nil?

    index = stops.size + 1 if !index || index < 0
    shift_index(index)
    stop = stops.build(type: StopStore.name, store: store, index: index, active: active, id: stop_id)
    self.outdated = true
    stop
  end

  def add(visit, index = nil, active = false, stop_id = nil)
    index = stops.size + 1 if !index || index < 0
    shift_index(index)
    stops.build(type: StopVisit.name, visit: visit, index: index, active: active, id: stop_id)
    self.outdated = true
  end

  def add_rest(active = true, stop_id = nil)
    index = stops.size + 1
    stops.build(type: StopRest.name, index: index, active: active, id: stop_id)
    self.outdated = true
  end

  def add_or_update_rest(active = true, stop_id = nil)
    if !stops.find{ |stop| stop.is_a?(StopRest) }
      add_rest(active, stop_id)
    end
    self.outdated = true
  end

  def remove_visit(visit)
    stops.find{ |stop|
      if stop.is_a?(StopVisit) && stop.visit == visit
        remove_stop(stop)
      end
    }
  end

  def remove_rests
    stops.each{ |stop|
      remove_stop(stop) if stop.is_a?(StopRest)
    }
  end

  def remove_store(stop)
    return if !stop.is_a?(StopStore)

    move_stop_out(stop)
  end

  def move_stop(stop, index)
    index = stops_size if index < 0
    if stop.index
      if index < stop.index
        shift_index(index, 1, stop.index - 1)
      else
        shift_index(stop.index + 1, -1, index)
      end
      stop.index = index
    end
    self.outdated = true
  end

  def move_stop_out(stop, force = false)
    return if !force && stop.is_a?(StopRest)

    shift_index(stop.index + 1, -1)
    self.stops.destroy(stop)
    self.outdated = true
  end

  def force_reindex
    # Force reindex after customers.destination.destroy_all
    stops.sort_by(&:index).each_with_index{ |stop, index|
      stop.index = index + 1
    }
  end

  def sum_out_of_window
    stops.to_a.sum{ |stop|
      if stop.time
        open, close = stop.best_open_close(stop.time)
        (open && stop.time < open ? open - stop.time : 0) + (close && stop.time > close ? stop.time - close : 0)
      else
        0
      end
    }
  end

  def active(action)
    stops.each{ |stop|
      if [:reverse, :all, :none].include?(action)
        stop.active = action == :reverse ? !stop.active : action == :all
      elsif [:status_any, :status_none].include?(action)
        stop.active = action == :status_none ? stop.status.nil? : !!stop.status
      else
        stop.active = stop.status && stop.status.downcase == action.to_s
      end
    }
    self.outdated = true
    true
  end

  def size_active
    Rails.application.config.planner_cache.fetch("#{cache_key_with_version}/active_stops") do
      vehicle_usage_id ? (stops.loaded? ? stops.select(&:active).size : stops.where(active: true).count) : 0
    end
  end

  def stops_size
    Rails.application.config.planner_cache.fetch("#{cache_key_with_version}/stops_size") do
      stops.size
    end
  end

  def size_destinations
    Rails.application.config.planner_cache.fetch("#{cache_key_with_version}/destination_stops") do
      stops.loaded? ?
        stops.select(&:active).map{ |s| s.is_a?(StopVisit) ? s.visit.destination_id : nil }.compact.uniq.size :
        nil # TODO: should count with ActiveRecord::Base.connection.execute("SELECT COUNT(DISTINCT id) FROM destinations")
    end
  end

  def no_geolocalization
    Rails.application.config.planner_cache.fetch("#{cache_key_with_version}/no_location_stops") do
      stops.loaded? ?
        stops.any?{ |s| s.is_a?(StopVisit) && !s.position? } :
        stops.joins(visit: :destination).where('destinations.lat IS NULL AND destinations.lng IS NULL').count > 0
    end
  end

  def no_path
    Rails.application.config.planner_cache.fetch("#{cache_key_with_version}/no_path_stops") do
      vehicle_usage_id && (stop_no_path ||
        (stops.loaded? ?
          stops.any?{ |s| s.is_a?(StopVisit) && s.no_path } :
          stops.select(:no_path).where(type: 'StopVisit', no_path: true).count > 0))
    end
  end

  [:unmanageable_capacity, :out_of_window, :out_of_capacity, :out_of_drive_time, :out_of_force_position, :out_of_work_time, :out_of_max_distance, :out_of_relation, :out_of_skill].each do |s|
    define_method "#{s}" do
      Rails.application.config.planner_cache.fetch("#{cache_key_with_version}/out_of_#{s}_cache") do
        vehicle_usage_id && (respond_to?("stop_#{s}") && send("stop_#{s}") ||
          if stops.loaded?
            stops.any?(&s)
          else
            h = {}
            h[s] = true
            stops.select(s).where(h).count > 0
          end)
      end
    end
  end

  include LocalizedAttr

  attr_localized :pickups
  attr_localized :deliveries

  def compute_loads(stops_sort = nil)
    stop_load_hash = {}
    r_pickups = QuantityAttr::QuantityHash.new(0) # Load at end store
    r_deliveries = QuantityAttr::QuantityHash.new(0) # Intermediate loads at stores
    r_start_deliveries = nil # Load at start store
    previous_store_stop = nil

    # First: Compute the store loads
    (stops_sort || stops).each{ |stop|
      next if !stop.active

      case stop.class.name
      when StopVisit.name
        stop.visit.default_pickups.each{ |k, v|
          r_pickups[k] += (v || 0)
        }
        stop.visit.default_deliveries.each{ |k, v|
          r_deliveries[k] += (v || 0)
        }
      when StopStore.name
        if previous_store_stop
          # The load of intermediate stores is the sum of the subsequent stop deliveries (r_deliveries)
          previous_store_stop.loads = r_deliveries.dup
        else
          # The load at start is the sum of deliveries at the first encountered store
          r_start_deliveries = r_deliveries.dup
        end
        r_deliveries = QuantityAttr::QuantityHash.new(0)
        r_pickups = QuantityAttr::QuantityHash.new(0)
        previous_store_stop = stop
      end
    }
    previous_store_stop.loads = r_deliveries.dup if previous_store_stop
    self.pickups = r_pickups
    self.deliveries = r_start_deliveries || r_deliveries

    current_loads = (r_start_deliveries || r_deliveries).dup

    # Second: Compute the StopVisit loads
    (stops_sort || stops).each { |stop|
      case stop.class.name
      when StopVisit.name
        process_stop_loads(stop, current_loads)
      when StopStore.name
        current_loads = stop.loads.dup
      end

      stop_load_hash[stop.id] = current_loads
      current_loads = current_loads.dup
    }
    [stop_load_hash, pickups, deliveries]
  end

  def max_loads
    units = planning.customer.deliverable_units

    max_loads = {}
    units.each { |unit|
      max_loads[unit.id] = deliveries[unit.id] || 0
      stops.each { |stop|
        if !stop.is_a?(StopRest)
          max_loads[unit.id] = [max_loads[unit.id], stop.loads[unit.id] || 0].max
        end
      }
    }
    max_loads
  end

  def reverse_order
    stops.sort_by{ |stop| -stop.index }.each_with_index{ |stop, index|
      stop.index = index + 1
    }
    self.outdated = true
  end

  # Split stops by active status, position and rest
  def stops_segregate(**options)
    stops.group_by{ |stop|
      !!(stop.active || options[:moving_stop_ids]&.include?(stop.id)) && (stop.position? || stop.is_a?(StopRest))
    }
  end

  def outdated=(value)
    if vehicle_usage? && !value.nil?
      self.optimized_at = nil unless in_optimization_context?
      self.last_sent_to = self.last_sent_at = nil
    end
    super(value)
  end

  def vehicle_usage?
    self.vehicle_usage_id || self.vehicle_usage
  end

  def changed?
    @stops_updated || @vehicle_color_changed || super
  end

  def set_send_to(name)
    self.last_sent_to = name
    self.last_sent_at = Time.now.utc
  end

  def clear_sent_to
    self.last_sent_to = self.last_sent_at = nil
  end

  def default_color
    self.color || (self.vehicle_usage? && self.vehicle_usage.vehicle.color) || Planner::Application.config.route_color_default
  end

  def to_s
    "#{ref}:#{vehicle_usage? && vehicle_usage.vehicle.name}=>[" + stops.collect(&:to_s).join(', ') + ']'
  end

  def self.routes_to_geojson(routes, include_stores = true, respect_hidden = true, include_linestrings = :polyline, with_quantities = false, large = false)
    stores_geojson = []
    final_features = []

    if include_stores
      stores_geojson =
        routes.select(&:vehicle_usage?)
              .map(&:vehicle_usage)
              .flat_map { |vu|
                [vu.default_store_start, vu.default_store_stop, vu.default_store_rest]
              }
              .compact
              .uniq
              .select(&:position?)
              .map do |store|
                coordinates = [store.lng, store.lat]
                {
                  type: 'Feature',
                  geometry: {
                    type: 'Point',
                    coordinates: coordinates
                  },
                  properties: {
                    store_id: store.id,
                    color: store.color,
                    icon: store.icon,
                    icon_size: store.icon_size
                  }
                }.to_json unless coordinates.empty?
              end.compact
    end

    features = routes.select { |r| !respect_hidden || !r.hidden }.flat_map { |r|
      (include_linestrings && r.geojson_tracks || []) +
        ((with_quantities ? r.stops_to_geojson_points(with_quantities: true) : r.geojson_points) || []).compact
    }.compact
    final_features += stores_geojson unless stores_geojson.empty?

    final_features += simplify_polyline_features(routes, features, { linestring: include_linestrings, large: large })

    '{"type":"FeatureCollection","features":[' + final_features.join(',') + ']}'
  end

  def to_geojson(include_stores = true, respect_hidden = true, include_linestrings = :polyline, with_quantities = false)
    self.class.routes_to_geojson([self], include_stores, respect_hidden, include_linestrings, with_quantities)
  end

  # Add route_id to geojson after create
  def complete_geojson
    self.geojson_tracks = self.geojson_tracks && self.geojson_tracks.map{ |s|
      linestring = JSON.parse(s)
      linestring['properties']['route_id'] = self.id
      linestring.to_json
    }
    self.geojson_points = self.geojson_points && self.geojson_points.map{ |s|
      point = JSON.parse(s)
      point['properties']['route_id'] = self.id
      point.to_json
    }
    self.update_columns(attributes.slice('geojson_tracks', 'geojson_points'))
  end

  def stops_to_geojson_points(options = {})
    return if stops.empty?

    units = planning.customer.deliverable_units

    inactive_stops = 0
    stops.map do |stop|
      inactive_stops += 1 unless stop.active

      next unless stop.position?

      feat = {
        type: 'Feature',
        geometry: {
          type: 'Point',
          coordinates: [stop.lng, stop.lat]
        },
        properties: {
          route_id: self.id,
          index: stop.index,
          active: stop.active,
          number: vehicle_usage? ? stop.number(inactive_stops) : nil,
          color: stop.default_color,
          icon: stop.icon,
          icon_size: stop.icon_size,
          stop_id: stop.id
        }
      }

      if options[:with_quantities] && stop.is_a?(StopVisit)
        feat[:properties][:quantities] = []
        units.each{ |unit|
          feat[:properties][:quantities] << {
            deliverable_unit_id: unit.id,
            quantity: (stop.visit.default_deliveries[unit.id] || 0) - (stop.visit.default_pickups[unit.id] || 0),
            pickup: stop.visit.default_pickups[unit.id] || 0,
            delivery: stop.visit.default_deliveries[unit.id] || 0
          }
        }
      end
      feat.to_json
    end.compact
  end

  def speed_average(unit = 'km')
    converter = (unit == 'km') ? 3.6 : 2.237
    ((self.distance / (self.drive_time | 1)) * converter).round
  end

  def clear_eta_data
    self.departure_eta = nil
    self.departure_status = nil
    self.arrival_eta = nil
    self.arrival_status = nil
  end

  def compute_out_of_force_position
    stops.each{ |stop| stop.out_of_force_position = nil }

    # default scope is sorted by index but in case of a move preloaded order might be invalid
    stops_sort = stops.sort_by(&:index)

    position_status = :first
    previous_stop = nil
    stops_sort.each{ |stop|
      next if !stop.is_a?(StopVisit) || !stop.active

      if position_status == :first
        if !stop.visit.always_first?
          position_status = nil
        end
        if stop.visit.never_first? && previous_stop.nil?
          stop.out_of_force_position = true
        end
      end

      if position_status != :first && stop.visit.always_first?
        stop.out_of_force_position = true
      end

      previous_stop = stop
    }

    position_status = :final
    stops_sort.reverse.each{ |stop|
      next if !stop.is_a?(StopVisit) || !stop.active

      if position_status == :final
        if !stop.visit.always_final?
          position_status = nil
        end
      end

      if position_status != :final && stop.visit.always_final?
        stop.out_of_force_position = true
      end
    }
  end

  def route_skills
    return [] if !vehicle_usage?

    vehicle_usage.tags | vehicle_usage.vehicle.tags
  end

  def compute_out_of_skill
    planning_skills = planning.all_skills.map(&:id)

    return if planning_skills.empty?

    r_skills = route_skills.map(&:id)

    stops.each{ |stop|
      next if !stop.is_a?(StopVisit) || !stop.active

      stop_tags = stop.visit.tags | stop.visit.destination.tags
      stop_skills = stop_tags.map(&:id) & planning_skills

      stop.out_of_skill = stop_skills.any? && (stop_skills & r_skills).size < stop_skills.size
    }
  end

  def compute_out_of_relations
    stops.each{ |s| s.out_of_relation = false }

    stop_hash = {}
    route_relations = stops.flat_map{ |stop|
      next unless stop.is_a?(StopVisit)

      stop_hash[stop.visit.id] = stop
      stop.visit.relation_currents + stop.visit.relation_successors
    }.compact.uniq

    route_relations.each{ |relation|
      if !stop_hash[relation.current_id] || !stop_hash[relation.successor_id]
        # Both current and successor should belong to the plan
        stop_hash[relation.current_id]&.out_of_relation = true
        stop_hash[relation.successor_id]&.out_of_relation = true
      elsif stop_hash[relation.current_id].route.id != stop_hash[relation.successor_id].route.id ||
            stop_hash[relation.current_id].active != stop_hash[relation.successor_id].active
        # All relations implies that stops belongs to the same route and should be both or none active
        stop_hash[relation.current_id].out_of_relation = true
        stop_hash[relation.successor_id].out_of_relation = true
      elsif RELATION_ORDER_KEYS.include?(relation.relation_type.to_sym) && stop_hash[relation.current_id].index > stop_hash[relation.successor_id].index
        # Most of relations implies to have ordered stop indices
        stop_hash[relation.current_id].out_of_relation = true
        stop_hash[relation.successor_id].out_of_relation = true
      elsif relation.relation_type == 'sequence' && (stop_hash[relation.current_id].index + 1) != stop_hash[relation.successor_id].index
        # Sequence implies that successor is right after current stop in route
        stop_hash[relation.current_id].out_of_relation = true
        stop_hash[relation.successor.id].out_of_relation = true
      end
    }
  end

  def preload_compute_scopes
    Route.where(id: self.id).includes_vehicle_usages.includes_destinations_and_stores.first
  end

  def import_attributes
    self.attributes.except('lock_version')
  end

  def invalidate_planning_cache
    planning.invalidate_planning_cache
  end

  def invalidate_route_cache
    @traces = nil
    Rails.application.config.planner_cache.delete("#{self.cache_key_with_version}/active_stops")
    Rails.application.config.planner_cache.delete("#{self.cache_key_with_version}/stops_size")
    Rails.application.config.planner_cache.delete("#{self.cache_key_with_version}/destination_stops")
    Rails.application.config.planner_cache.delete("#{self.cache_key_with_version}/no_location_stops")
    Rails.application.config.planner_cache.delete("#{self.cache_key_with_version}/no_path_stops")
    [:unmanageable_capacity, :out_of_window, :out_of_capacity, :out_of_drive_time, :out_of_force_position, :out_of_work_time, :out_of_max_distance, :out_of_relation, :out_of_skill].each do |s|
      Rails.application.config.planner_cache.delete("#{self.cache_key_with_version}/out_of_#{s}_cache")
    end
  end

  private

  def assign_defaults
    self.hidden = false
    self.locked = false
  end

  def in_optimization_context?
    planning&.in_optimization_context?
  end

  def remove_stop(stop)
    shift_index(stop.index + 1, -1)
    self.outdated = true
    stops.destroy(stop) # Must return a value
  end

  def shift_index(from, by = 1, to = nil)
    stops.partition{ |stop|
      stop.index < from || (to && stop.index > to)
    }[1].each{ |stop|
      stop.index += by
    }
  end

  def stop_index_validation
    if !@no_stop_index_validation && (@stops_updated || @computed) && !stops.empty? && stops.collect(&:index).sum != (stops.length * (stops.length + 1)) / 2
      # Workaround as long as bad index has no solution recompute indices
      reset_indices
      raise Exceptions::StopIndexError.new(self)
    end

    @no_stop_index_validation = nil
  rescue Exceptions::StopIndexError => e
    Sentry.capture_exception(e)
    Rails.logger.error e.message
    Rails.logger.error e.backtrace.join("\n")
  end

  def reset_indices
    stops.each.with_index{ |stop, index|
      stop.index = index + 1
    }
  end

  def update_stops_track(_stop)
    self.outdated = true unless new_record?
    @stops_updated = true
  end

  # When route is created, rest is already set in init_stops
  def update_vehicle_usage
    if vehicle_usage_id_changed?
      if vehicle_usage.default_rest_duration.nil?
        stops.select{ |stop| stop.is_a?(StopRest) }.each{ |stop|
          remove_stop(stop)
        }
      elsif stops.none?{ |stop| stop.is_a?(StopRest) }
        add_rest
      end
      self.outdated = true
    end
  end

  # Update geojson without need of computing route
  def update_geojson
    if color_changed? || @vehicle_color_changed
      self.geojson_tracks = self.geojson_tracks && self.geojson_tracks.map{ |s|
        linestring = JSON.parse(s)
        linestring['properties']['color'] = self.default_color
        linestring.to_json
      }
      self.geojson_points = stops_to_geojson_points
    end
  end

  def self.simplify_polyline_features(routes, features, options = {})
    final_features = []
    if options[:linestring] == true
      polyline_features = []
      features = features.each { |feature|
        next final_features << feature unless feature.include?('polylines')

        polyline_feature = JSON.parse(feature)
        SimplifyGeometry.polylines_to_coordinates(polyline_feature, **{ precision: 1e-6, skip_simplifier: true })
        polyline_features << polyline_feature
      }

      if options[:large] && routes.size > 1
        final_features += merge_linestrings(polyline_features)
      else
        final_features += polyline_features.map(&:to_json)
      end
    else
      final_features += features
    end
    final_features
  end

  def self.merge_linestrings(polyline_features)
    final_features = []
    polyline_features.group_by{ |ft| ft['properties']['route_id'] }.each{ |route_id, fts|
      drive_time = fts.map{ |ft| ft['properties']['drive_time'].to_i }.reduce(&:+)
      distance = fts.map{ |ft| ft['properties']['distance'].to_f }.reduce(&:+)
      linestring = fts.map{ |ft| ft['geometry']['coordinates'] }.reduce(&:+)

      fts.first['geometry']['drive_time'] = drive_time
      fts.first['properties']['distance'] = distance
      fts.first['geometry']['coordinates'] = linestring
      final_features << fts.first.to_json
    }
    final_features
  end

  def process_stop_loads(stop, current_loads)
    @deliverable_units ||= planning.customer.deliverable_units
    return if !stop.active || !stop.position? || !stop.is_a?(StopVisit) || !stop.visit.default_quantities?

    @default_capacities ||= vehicle_usage&.vehicle&.default_capacities
    default_pickups = stop.visit.default_pickups
    default_deliveries = stop.visit.default_deliveries
    out_of_capacity = nil
    unmanageable_capacity = nil

    @deliverable_units.each do |du|
      if vehicle_usage
        # Is the vehicle in overload/underload arriving at the stop ?
        out_of_capacity ||= current_loads[du.id] && (@default_capacities[du.id] && current_loads[du.id].round(2) > @default_capacities[du.id].round(2) || current_loads[du.id].round(2) < 0)
        pickup = default_pickups[du.id]
        delivery = default_deliveries[du.id]
        current_loads[du.id] =
          (current_loads[du.id] || 0) + (pickup || 0) - (delivery || 0)
        has_pickup = pickup && pickup > 0
        has_delivery = delivery && delivery > 0
        # Is the vehicle in overload/underload leaving the stop ?
        out_of_capacity ||= current_loads[du.id] && (@default_capacities[du.id] && current_loads[du.id].round(2) > @default_capacities[du.id].round(2) || current_loads[du.id].round(2) < 0)
        unmanageable_capacity ||= (has_pickup || has_delivery) && (!@default_capacities.key?(du.id) || @default_capacities[du.id] == 0)
      end
    end
    stop.loads = current_loads
    stop.unmanageable_capacity = unmanageable_capacity
    stop.out_of_capacity = out_of_capacity

    current_loads
  end
end
