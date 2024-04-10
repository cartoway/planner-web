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
class Route < ApplicationRecord
  RELATION_ORDER_KEYS = %i[pickup_delivery order sequence]

  belongs_to :planning
  belongs_to :vehicle_usage
  has_many :stops, inverse_of: :route, autosave: true, dependent: :delete_all, after_add: :update_stops_track, after_remove: :update_stops_track
  serialize :quantities, DeliverableUnitQuantity

  nilify_blanks
  validates :planning, presence: true
#  validates :vehicle_usage, presence: true # nil on unplanned route
  validate :stop_index_validation
  attr_accessor :no_stop_index_validation, :vehicle_color_changed

  include TimeAttr
  attribute :start, ScheduleType.new
  attribute :end, ScheduleType.new
  time_attr :start, :end

  before_update :update_vehicle_usage, :update_geojson

  after_initialize :assign_defaults, if: 'new_record?'
  after_create :complete_geojson
  after_save { @computed = false }

  scope :for_customer_id, ->(customer_id) { joins(:planning).where(plannings: {customer_id: customer_id}) }
  scope :includes_vehicle_usages, -> { includes(vehicle_usage: [:vehicle_usage_set, :store_start, :store_stop, :store_rest, vehicle: [:customer]]) }
  scope :includes_stops, -> { includes(:stops) }
  # The second visit is for counting the visit index from all the visits of the destination
  scope :includes_destinations, (-> { includes(stops: {visit: [:tags, destination: %i[tags customer visits]]}) })
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

  # FIXME, probaly not in the rails ways
  # Flag outdated if force_start changes
  def force_start=(v)
    if self.force_start != v
      self.outdated = true
    end
    super(v)
  end

  # FIXME, probaly not in the rails ways
  # Flag outdated if start changes
  def start=(v)
    if self.start != v
      self.outdated = true
    end
    super(v)
  end

  def init_stops(compute = true, ignore_errors = false)
    stops.clear
    if vehicle_usage? && vehicle_usage.default_rest_duration
      stops.build(type: StopRest.name, active: true, index: 1)
    end

    compute!(ignore_errors: ignore_errors) if compute
  end

  def default_stops
    i = stops.size
    planning.visits_compatibles.each { |visit|
      stops.build(type: StopVisit.name, visit: visit, active: true, index: i += 1)
    }
    self.outdated = true
  end

  def service_time_start_value
    vehicle_usage.default_service_time_start if vehicle_usage? && vehicle_usage.default_service_time_start
  end

  def service_time_end_value
    vehicle_usage.default_service_time_end if vehicle_usage? && vehicle_usage.default_service_time_end
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
      emission: nil,
      start: nil,
      end: nil,
      distance: 0,
      drive_time: nil,
      wait_time: nil,
      visits_duration: nil,
      quantities: nil
    }
  end

  def store_traces(geojson_tracks, trace, options = {})
    if trace && !options[:no_geojson]
      geojson_tracks << {
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

    self.touch if self.id # To force route save in case none attribute has changed below

    geojson_tracks = []

    last_lat, last_lng = nil, nil
    route_attributes = init_route_data

    if vehicle_usage?
      service_time_start = service_time_start_value
      service_time_end = service_time_end_value
      route_attributes[:end] = route_attributes[:start] = departure || vehicle_usage.default_time_window_start
      speed_multiplier = vehicle_usage.vehicle.default_speed_multiplier
      if vehicle_usage.default_store_stop.try(&:position?)
        last_lat, last_lng = vehicle_usage.default_store_stop.lat, vehicle_usage.default_store_stop.lng
      end
      router = vehicle_usage.vehicle.default_router
      router_dimension = vehicle_usage.vehicle.default_router_dimension
      stops_drive_time = {}

      # Add service time
      unless service_time_start.nil?
        route_attributes[:end] += service_time_start
      end

      stops_sort = stops.sort_by(&:index)

      # Collect route legs
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

      if !last_lat.nil? && !last_lng.nil? && vehicle_usage.default_store_start.try(&:position?)
        segments.insert(0, [vehicle_usage.default_store_start.lat, vehicle_usage.default_store_start.lng, last_lat, last_lng])
      else
        segments.insert(0, nil)
      end

      # Compute legs traces
      begin
        router_options = vehicle_usage.vehicle.default_router_options.symbolize_keys
        router_options[:geometry] = false if options[:no_geojson]
        router_options[:speed_multiplier] = speed_multiplier
        router_options[:speed_multiplier_areas] = Zoning.speed_multiplier_areas(planning.zonings)
        # Use Time.zone.parse to preserve time zone from user (instead of to_time)
        router_options[:departure] = Time.zone.parse((planning.date || Date.today).to_s) + departure if departure

        ts = router.trace_batch(segments.reject(&:nil?), router_dimension, router_options)
        traces = segments.collect{ |segment|
          if segment.nil?
            [nil, nil, nil]
          else
            (ts && !ts.empty? && ts.shift) || [nil, nil, nil]
          end
        }
      rescue RouterError
        raise unless options[:ignore_errors]
        traces = [nil, nil, nil] * segments.size
      end
      traces[0] = [0, 0, nil] unless vehicle_usage.default_store_start.try(&:position?)

      # Recompute Stops
      stops_time_windows = {}
      previous_with_pos = vehicle_usage.default_store_start.try(:position?)
      stops_sort.each{ |stop|
        if stop.active && (stop.position? || (stop.is_a?(StopRest) && ((stop.time_window_start_1 && stop.time_window_end_1) || (stop.time_window_start_2 && stop.time_window_end_2)) && stop.duration))
          stop.distance, stop.drive_time, trace = traces.shift
          stop.no_path = previous_with_pos && stop.position? && trace.nil?
          previous_with_pos = stop if stop.position?

          store_traces(geojson_tracks, trace, options.merge(drive_time: stop.drive_time, distance: stop.distance))

          if stop.drive_time
            stops_drive_time[stop] = stop.drive_time
            stop.time = route_attributes[:end] + stop.drive_time
            route_attributes[:drive_time] = (route_attributes[:drive_time] || 0) + stop.drive_time
          elsif !stop.no_path
            stop.time = route_attributes[:end]
          else
            stop.time = nil
          end

          if stop.time
            open, close, late_wait = stop.best_open_close(stop.time)
            stops_time_windows[stop] = [open, close]
            if open && stop.time < open
              stop.wait_time = open - stop.time
              stop.time = open
              route_attributes[:wait_time] = (route_attributes[:wait_time] || 0) + stop.wait_time
            else
              stop.wait_time = nil
            end
            stop.out_of_window = !!(late_wait && late_wait > 0)

            route_attributes[:distance] += stop.distance if stop.distance
            route_attributes[:end] = stop.time + stop.duration
            route_attributes[:visits_duration] = (route_attributes[:visits_duration] || 0) + stop.duration if stop.is_a?(StopVisit)

            stop.out_of_drive_time = stop.time > vehicle_usage.default_time_window_end
            stop.out_of_work_time = vehicle_usage.outside_default_work_time?(route_attributes[:start], stop.time)
            max_distance = vehicle_usage.vehicle.max_distance || planning.vehicle_usage_set.max_distance
            stop.out_of_max_distance = max_distance ? route_attributes[:distance] > max_distance : false
          end
        else
          stop.active = stop.out_of_capacity = stop.out_of_drive_time = stop.out_of_window = stop.no_path = stop.out_of_work_time = stop.out_of_max_distance = false
          stop.distance = stop.time = stop.wait_time = nil
        end
      }

      route_attributes[:quantities] = compute_quantities(stops_sort) unless options[:no_quantities]

      # Last stop to store
      distance, drive_time, trace = traces.shift
      if drive_time
        route_attributes[:distance] += distance
        stops_drive_time[:stop] = drive_time
        route_attributes[:end] += drive_time
        route_attributes[:stop_distance], route_attributes[:stop_drive_time] = distance, drive_time
        route_attributes[:drive_time] += drive_time if route_attributes[:drive_time]
      end
      route_attributes[:stop_no_path] = vehicle_usage.default_store_stop.try(:position?) && stops_sort.any?{ |s| s.active && s.position? } && trace.nil?

      # Add service time to end point
      route_attributes[:end] += service_time_end unless service_time_end.nil?

      store_traces(geojson_tracks, trace, options.merge(drive_time: drive_time, distance: stop_distance))
      route_attributes[:geojson_tracks] = geojson_tracks unless options[:no_geojson]
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
      stops_sort, stops_drive_time, stops_time_windows = plan(
        # Hack to allow manual set of self.start from the API and keep the value
        # when used in conjunction with self.force_start
        self.force_start ? self.start : vehicle_usage.default_time_window_start,
        options
      )

      if stops_sort
        compute_out_of_force_position
        compute_out_of_relations

        # Try to minimize waiting time by a later begin
        time = self.end
        time -= stops_drive_time[:stop] if stops_drive_time[:stop]
        time -= vehicle_usage.default_service_time_end if vehicle_usage.default_service_time_end
        stops_sort.reverse_each{ |stop|
          if stop.active && (stop.position? || stop.is_a?(StopRest))
            _open, close = stops_time_windows[stop]
            if stop.time && (stop.out_of_window || (close && time > close))
              time = [stop.time, close ? close - stop.duration : 0].max
            else
              # Latest departure time
              time = [time, close].min if close

              # New arrival stop time
              time -= stop.duration
            end

            # Previous departure time
            time -= stops_drive_time[stop] if stops_drive_time[stop]
          end
        }

        time -= vehicle_usage.default_service_time_start if vehicle_usage.default_service_time_start

        force_start = !self.force_start.nil? ? self.force_start : planning.customer.optimization_force_start.nil? ? Mapotempo::Application.config.optimize_force_start : planning.customer.optimization_force_start
        if time > start && !force_start
          # We can sleep a bit more on morning, shift departure
          plan(time, options)
        end
      end
    else
      self.quantities = compute_quantities unless options[:no_quantities]
    end

    self.geojson_points = stops_to_geojson_points unless options[:no_geojson]

    self.outdated = false
    @computed = true
    true
  end

  def compute(options = {})
    compute!(options) if self.outdated
    true
  end

  def set_visits(visits, recompute = true, ignore_errors = false)
    Stop.transaction do
      init_stops false
      add_visits visits, recompute, ignore_errors
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

  def move_stop(stop, index)
    index = stops.size if index < 0
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
    if force || stop.is_a?(StopVisit)
      shift_index(stop.index + 1, -1)
      stop.route.stops.destroy(stop)
      self.outdated = true
    end
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
    vehicle_usage_id ? (stops.loaded? ? stops.select(&:active).size : stops.where(active: true).count) : 0
  end

  def size_destinations
    stops.loaded? ?
      stops.select(&:active).map{ |s| s.is_a?(StopVisit) ? s.visit.destination_id : nil }.compact.uniq.size :
      nil # TODO: should count with ActiveRecord::Base.connection.execute("SELECT COUNT(DISTINCT id) FROM destinations")
  end

  def no_geolocalization
    stops.loaded? ?
      stops.any?{ |s| s.is_a?(StopVisit) && !s.position? } :
      stops.joins(visit: :destination).where('destinations.lat IS NULL AND destinations.lng IS NULL').count > 0
  end

  def no_path
    vehicle_usage_id && (stop_no_path ||
      (stops.loaded? ?
        stops.any?{ |s| s.is_a?(StopVisit) && s.no_path } :
        stops.select(:no_path).where(type: 'StopVisit', no_path: true).count > 0))
  end

  [:unmanageable_capacity, :out_of_window, :out_of_capacity, :out_of_drive_time, :out_of_force_position, :out_of_work_time, :out_of_max_distance, :out_of_relation].each do |s|
    define_method "#{s}" do
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

  include LocalizedAttr

  attr_localized :quantities

  def compute_quantities(stops_sort = nil)
    return {} if planning.customer.deliverable_units.empty?

    quantities_ = Hash.new(0)

    (stops_sort || stops).each do |stop|
      if stop.active && stop.position? && stop.is_a?(StopVisit)
        out_of_capacity = nil
        unmanageable_capacity = nil

        stop.route.planning.customer.deliverable_units.each do |du|
          if vehicle_usage && (stop.visit.quantities_operations[du.id].nil? || stop.visit.quantities_operations[du.id].empty?)
            quantities_[du.id] = (quantities_[du.id] || 0) + (stop.visit.default_quantities[du.id] || 0)
          elsif vehicle_usage && stop.visit.quantities_operations[du.id] == 'fill'
            quantities_[du.id] = vehicle_usage.vehicle.default_capacities[du.id] if vehicle_usage.vehicle.default_capacities[du.id]
          elsif vehicle_usage && stop.visit.quantities_operations[du.id] == 'empty'
            quantities_[du.id] = 0
          end

          if vehicle_usage
            # In this case, we reckon the stop as not out of its capacity. Because he's not going to deliver anything.
            quantity = stop.visit.default_quantities[du.id]
            skip_quantity = quantity.nil? || quantity == 0
            # Don't evaluate out_of_capacity if already valuated by the a previous deliverable unit.
            out_of_capacity ||= !skip_quantity & ((vehicle_usage.vehicle.default_capacities[du.id] && quantities_[du.id] > vehicle_usage.vehicle.default_capacities[du.id]) || quantities_[du.id] < 0)  # FIXME with initial quantity
            unmanageable_capacity ||= !quantity.nil? && (quantity != 0 && vehicle_usage.vehicle.default_capacities[du.id] == 0)
          end

        end if stop.visit.try(:default_quantities?) # Avoid N+1 queries

        stop.unmanageable_capacity = unmanageable_capacity
        stop.out_of_capacity = out_of_capacity
      end
    end

    quantities_.each { |k, v|
      v = v.round(3)
    }
  end

  def reverse_order
    stops.sort_by{ |stop| -stop.index }.each_with_index{ |stop, index|
      stop.index = index + 1
    }
    self.outdated = true
  end

  # Split stops by active status, position and rest
  def stops_segregate(active_only = true)
    stops.group_by{ |stop| (!active_only ? true : stop.active) && (stop.position? || stop.is_a?(StopRest)) }
  end

  def outdated=(value)
    if vehicle_usage? && value
      self.optimized_at = nil unless optimized_at_changed?
      self.last_sent_to = self.last_sent_at = nil
    end
    self['outdated'] = value
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
    self.color || (self.vehicle_usage? && self.vehicle_usage.vehicle.color) || Mapotempo::Application.config.route_color_default
  end

  def to_s
    "#{ref}:#{vehicle_usage? && vehicle_usage.vehicle.name}=>[" + stops.collect(&:to_s).join(', ') + ']'
  end

  def self.routes_to_geojson(routes, include_stores = true, respect_hidden = true, include_linestrings = :polyline, with_quantities = false, large = false)
    stores_geojson = []
    final_features = []

    if include_stores
      stores_geojson = routes.select(&:vehicle_usage?).map(&:vehicle_usage).flat_map { |vu| [vu.default_store_start, vu.default_store_stop, vu.default_store_rest] }.compact.uniq.select(&:position?).map do |store|
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
    unless stops.empty?
      inactive_stops = 0
      stops.sort_by(&:index).map do |stop|
        inactive_stops += 1 unless stop.active
        if stop.position?
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
              icon_size: stop.icon_size
            }
          }
          feat[:properties][:quantities] = stop.visit.default_quantities.map { |k, v|
            {
              deliverable_unit_id: k,
              quantity: v
            }
          } if options[:with_quantities] && stop.is_a?(StopVisit)
          feat.to_json
        end
      end.compact
    end
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
    stops_sort = stops.sort_by(&:index)

    position_status = :first
    previous_stop = nil
    stops_sort.each{ |stop|
      next if stop.is_a?(StopRest) || !stop.active

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
      next if stop.is_a?(StopRest) || !stop.active

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

  def compute_out_of_relations
    stops.each{ |s| s.out_of_relation = false }

    stop_hash = stops.only_stop_visits.map{ |stop| [stop.visit.id, stop] }.to_h
    stops_sort = stops.only_stop_visits.sort_by(&:index)

    route_relations = stops.only_stop_visits.includes_relations.flat_map{ |stop_visit|
      stop_visit.visit.relation_currents + stop_visit.visit.relation_successors
    }.uniq

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
    Route.includes_vehicle_usages.where(id: self.id).includes_destinations
  end

  private

  def assign_defaults
    self.hidden = false
    self.locked = false
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
    Raven.capture_exception(e)
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
        SimplifyGeometry.polylines_to_coordinates(polyline_feature, { precision: 1e-6, skip_simplifier: true })
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
end
