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
class Planning < ApplicationRecord
  RELATION_KEYS = { pickup_delivery: :shipment, ordered: :order, sequence: :sequence, same_vehicle: :same_vehicle }

  default_scope { includes(:tags).order(:id) }

  belongs_to :customer, counter_cache: true
  has_and_belongs_to_many :zonings, autosave: true, after_add: :update_zonings_track, after_remove: :update_zonings_track
  has_many :routes, -> { order("vehicle_usage_id NULLS FIRST") }, inverse_of: :planning, autosave: true, dependent: :delete_all

  has_many :tag_plannings
  has_many :tags, through: :tag_plannings, autosave: true, after_add: :update_tags_track, after_remove: :update_tags_track

  belongs_to :order_array, optional: true
  belongs_to :vehicle_usage_set, inverse_of: :plannings, validate: true

  nilify_blanks
  auto_strip_attributes :name

  enum tag_operation: [:_and, :_or]

  validates :customer, presence: true
  validates :name, presence: true
  validates :vehicle_usage_set, presence: true
  validates :begin_date, presence: true, if: :end_date
  validates :end_date, presence: true, if: :begin_date
  validate :begin_after_end_date

  include Consistency
  validate_consistency [:vehicle_usage_set, :order_array, :zonings, :tags]

  before_create :update_zonings, :check_max_planning
  before_destroy :unlink_job_optimizer
  before_save :update_vehicle_usage_set

  after_save :invalidate_planning_cache
  after_destroy :invalidate_planning_cache

  thread_mattr_accessor :optimizer_context

  include RefSanitizer

  scope :preload_routes_without_stops, -> {
    preload(
      routes: [
        vehicle_usage: [
          :store_start, :store_stop, :store_rest,
          {vehicle_usage_set: [:store_start, :store_stop, :store_rest]},
          {vehicle: [:router, {customer: :router}]}
        ]
      ],
      vehicle_usage_set: [
        { vehicle_usages: {vehicle: [:router, {customer: :router}]} }
      ]
    )
  }

  scope :preload_route_details, -> {
    preload(
      routes: [
        stops: [
          visit: [
            :relation_currents, :relation_successors, :tags,
            { destination: [:tags, {customer: :deliverable_units}] }
          ]
        ],
        vehicle_usage: [
          :store_start, :store_stop, :store_rest, :tags,
          {vehicle_usage_set: [:store_start, :store_stop, :store_rest]},
          {vehicle: [:router, :tags, {customer: :router}]}
        ]
      ],
      vehicle_usage_set: [
        { vehicle_usages: {vehicle: [:router, {customer: :router}]} }
      ]
    )
  }

  amoeba do
    enable

    customize(lambda { |_original, copy|
      def copy.update_zonings; end

      def copy.update_vehicle_usage_set; end

      copy.routes.each{ |route|
        route.planning = copy
      }
    })
  end

  def duplicate
    copy = self.amoeba_dup
    now = " (#{I18n.l(Time.zone.now, format: :long)})"
    copy.name += now
    copy.ref += now if self.ref
    copy
  end

  def invalidate_planning_cache
    Rails.application.config.planner_cache.delete("#{self.cache_key_with_version}/active_stops_sum")
    true
  end

  def cached_active_stops_sum
    Rails.application.config.planner_cache.fetch("#{cache_key_with_version}/active_stops_sum") do
      routes.to_a.sum(0) { |route| route.vehicle_usage_id ? route.size_active : 0 }
    end
  end

  def changed?
    routes_changed? || super
  end

  def in_optimization_context?
    self.class.optimizer_context
  end

  def set_routes(routes_visits, recompute = true, ignore_errors = false)
    default_empty_routes(ignore_errors)
    routes_visits = routes_visits.select{ |ref, _d| ref } # Remove out_of_route
    if routes_visits.size <= routes.size - 1
      visits = routes_visits.values.flat_map{ |s| s[:visits] }.collect{ |visit_active| visit_active[0] }
      # Set all excluded visits out of route
      routes.find{ |r| !r.vehicle_usage? }.set_visits((customer.visits - visits).select{ |visit|
        tags_compatible?(visit.tags.to_a | visit.destination.tags.to_a)
      })

      index_routes = (1..routes.size).to_a
      routes_visits.each{ |_ref, r|
        index_routes.delete(routes.index{ |rr| rr.vehicle_usage? && rr.vehicle_usage.vehicle.ref == r[:ref_vehicle] }) if r[:ref_vehicle]
      }
      routes_visits.each{ |ref, r|
        i = routes.index{ |rr| r[:ref_vehicle] && rr.vehicle_usage? && rr.vehicle_usage.vehicle.ref == r[:ref_vehicle] } || index_routes.shift
        routes[i].ref = ref
        routes[i].set_objects(r[:visits], recompute, ignore_errors)
      }
      true
    else
      false
    end
  end

  def update_routes(routes_visits, recompute = true)
    if routes_visits.size <= routes.size - 1
      existing_visits = routes.select{ |route| route.vehicle_usage? && routes_visits.key?(route.vehicle_usage.vehicle.ref&.downcase) }.flat_map{ |route| route.stops.map(&:visit) }
      stop_visit_ids = visits.each_with_object({}) { |visit, hash| hash[visit.id] = true }
      stop_store_ids = stores.each_with_object({}) { |store, hash| hash[store.id] = true }
      import_visits = routes_visits.flat_map{ |_ref, r| r[:visits] }

      routes.find{ |route| !route.vehicle_usage? }.add_visits(existing_visits - import_visits)

      index_routes = (1..routes.size).to_a
      routes_visits.each{ |_ref, r|
        index_routes.delete(routes.index{ |rr| rr.vehicle_usage? && rr.vehicle_usage.vehicle.ref&.downcase == r[:ref_vehicle] }) if r[:ref_vehicle]
      }

      routes_visits.each{ |ref, r|
        next if r[:visits].empty?

        i =
          if ref
            routes.index{ |rr| r[:ref_vehicle] && rr.vehicle_usage? && rr.vehicle_usage.vehicle.ref&.downcase == r[:ref_vehicle] } || index_routes.shift
          else
            routes.index{ |route| !route.vehicle_usage? }
          end
        routes[i].ref = ref
        r[:visits].each{ |obj, stop_attributes|
          if obj.is_a?(Visit)
            if obj.id && stop_visit_ids[obj.id]
              move_visit(routes[i], obj, -1)
            else
              routes[i].add(obj, nil, stop_attributes)
            end
          elsif obj.is_a?(Store)
            if obj.id && stop_store_ids[obj.id]
              move_store(routes[i], obj, -1)
            else
              routes[i].add_store(obj, nil, stop_attributes)
            end
          end
        }
      }
      true
    else
      false
    end
  end

  def vehicle_usage_add(vehicle_usage, ignore_errors = false)
    route = routes.build(vehicle_usage: vehicle_usage, outdated: false)
    vehicle_usage.routes << route unless vehicle_usage.id
    route.init_stops(true, ignore_errors)
  end

  def vehicle_usage_remove(vehicle_usage)
    route = routes.find{ |route| route.vehicle_usage == vehicle_usage }
    # route no longer exists if vehicle is disabled
    if route
      out_of_route = routes.find{ |r| !r.vehicle_usage? }
      route.stops.select{ |stop| stop.is_a?(StopVisit) }.map{ |stop|
        out_of_route.stops.build(type: StopVisit.name, visit: stop.visit, index: out_of_route.stops.length + 1)
      }
      routes.destroy(route)
    end
  end

  def visits_include?(visit)
    if self.id
      # Don't load all visits if it is not necessary
      !(visit.stop_visits.map(&:route_id) & routes.map(&:id)).empty?
    else
      visits.include?(visit)
    end
  end

  def visit_add(visit)
    update_routes_changed
    routes.find{ |r| !r.vehicle_usage? }.add(visit)
  end

  def visit_filling
    visit_ids = routes.includes_stops.flat_map{ |route| route.stops.map{ |stop| stop.visit_id }}
    Visit.includes_destinations.where(id: (customer.visit_ids - visit_ids)).select{ |visit|
      tags_compatible?(visit.tags.to_a | visit.destination.tags.to_a)
    }.each{ |visit| visit_add(visit) }
    self.save!
  end

  def visit_remove(visit)
    update_routes_changed
    routes.each{ |route|
      (visit.stop_visits.loaded? ? visit.stop_visits.map(&:route_id).include?(route.id) : true) && route.remove_visit(visit)
    }
  end

  def default_empty_routes(ignore_errors = false)
    routes.clear
    routes.build
    vehicle_usage_set.vehicle_usages.with_vehicle.select(&:active).each { |vehicle_usage|
      vehicle_usage_add(vehicle_usage, ignore_errors)
    }
  end

  def default_routes
    if vehicle_usage_set && routes.length != vehicle_usage_set.vehicle_usages.select(&:active).length + 1
      default_empty_routes

      if !split_by_zones(visits_compatibles)
        routes.find{ |r| !r.vehicle_usage? }.default_stops
      end
    end
  end

  def compute(options = {})
    routes.each{ |r|
      # Load necessary scopes just in time for outdated routes
      r.preload_compute_scopes if r.outdated && !options[:skip_preload]
      r.compute(options)
    }
  end

  def compute_saved(options = {})
    compute_saved!(options.merge(bang: false))
  end

  def compute_saved!(options = {})
    stop_rests = []
    stop_visits = []
    stop_stores = []

    # Collect all segments from all routes that need routing
    all_segments = []
    computed_routes = []

    routes.each{ |r|
      if options[:bang]!= false || r.outdated && r.vehicle_usage?
        computed_routes << r
        segments = r.collect_segments_for_routing(r.stops)
        all_segments << { route: r, segments: segments } if segments.any?
      end
    }

    # Batch process all segments in parallel
    precompute_traces(all_segments, options)

    computed_routes.each{ |r|
      if options[:bang] == false
        r.compute(options.merge(skip_preload: true))
      else
        r.compute!(options.merge(skip_preload: true))
      end
      stops_by_type = r.stops.group_by(&:type)
      stop_visits += stops_by_type['StopVisit'].to_a.map(&:import_attributes)
      stop_rests += stops_by_type['StopRest'].to_a.map(&:import_attributes)
      stop_stores += stops_by_type['StopStore'].to_a.map(&:import_attributes)

    }
    Route.import(computed_routes.map(&:import_attributes), validate_with_context: :update, raise_error: true, on_duplicate_key_update: {conflict_target: [:id], columns: :all})
    StopVisit.import(stop_visits, validate_with_context: :update, raise_error: true, on_duplicate_key_update: {conflict_target: [:id], columns: :all})
    StopRest.import(stop_rests, validate_with_context: :update, raise_error: true, on_duplicate_key_update: {conflict_target: [:id], columns: :all})
    StopStore.import(stop_stores, validate_with_context: :update, raise_error: true, on_duplicate_key_update: {conflict_target: [:id], columns: :all})

    computed_routes.each{ |r|
      r.invalidate_route_cache && r.reload
      next unless Planner::Application.config.delayed_job_use

      Delayed::Job.enqueue(SimplifyGeojsonTracksJob.new(self.customer_id, r.id))
    }
    self.save!(touch: false) && self.invalidate_planning_cache
    true
  end

  def precompute_traces(all_segments, options = {})
    if all_segments.any?
      threads = []
      all_segments.each_slice(5) do |batch|
        batch.each do |route_data|
          threads << Thread.new do
            begin
              ActiveRecord::Base.connection_pool.with_connection do
                route = route_data[:route]
                segments = route_data[:segments]
                router = route.vehicle_usage.vehicle.default_router
                router_options = route.vehicle_usage.vehicle.default_router_options.symbolize_keys
                router_options[:geometry] = false if options[:no_geojson]
                router_options[:speed_multiplier] = route.vehicle_usage.vehicle.default_speed_multiplier
                router_options[:speed_multiplier_areas] = Zoning.speed_multiplier_areas(self.zonings)
                router_options[:departure] = Time.zone.parse((self.date || Date.today).to_s) + route.start if route.start
                ts = router.trace_batch(segments.reject(&:nil?), route.vehicle_usage.vehicle.default_router_dimension, router_options)
                traces = segments.map{ |segment|
                  next [nil, nil, nil] if segment.nil?

                  (ts && !ts.empty? && ts.shift) || [nil, nil, nil]
                }
                route.store_precomputed_traces(traces, options)
              end
            rescue ActiveRecord::ConnectionTimeoutError
              Rails.logger.warn("Traces precompute failed for route #{route.id} because of connection timeout")
              # Do nothing, the compute will be performed by the route compute
            rescue RouterError
              raise unless options[:ignore_errors]
            end
          end
        end
        threads.each(&:join)
        threads.clear
      end
    end
  end

  def switch(route, vehicle_usage)
    previous_route = routes.find{ |route| route.vehicle_usage == vehicle_usage }
    if previous_route
      need_fetch_stop_status = previous_route.stops.any?(&:status)

      previous_vehicle_usage = route.vehicle_usage
      route.vehicle_usage = vehicle_usage
      previous_route.vehicle_usage = previous_vehicle_usage

      # Rest sticky with vehicle_usage
      previous_rests = previous_route.stops.select{ |stop| stop.is_a?(StopRest) }
      rests = route.stops.select{ |stop| stop.is_a?(StopRest) }
      previous_rests.each{ |rest|
        move_stop(route, rest, -1, true)
      }
      rests.each{ |rest|
        move_stop(previous_route, rest, -1, true)
      }

      fetch_stops_status if need_fetch_stop_status

      true
    else
      false
    end
  end

  def move_visit(route, visit, index)
    stop = nil
    routes.find do |route|
      stop = route.stops.find{ |s| s.visit_id == visit.id && s.type == 'StopVisit' }
    end

    if stop
      move_stop(route, stop, index)
    end
  end

  def move_store(route, store, index)
    stop = nil
    routes.find do |route|
      stop = route.stops.find{ |s| s.store_id == store.id && s.type == 'StopStore' }
    end

    if stop
      move_stop(route, stop, index)
    end
  end

  def move_stop(route, stop, index, force = false)
    route, index = prefered_route_and_index([route], stop) unless index || !route.vehicle_usage?

    if stop.route != route
      if stop.is_a?(StopVisit)
        visit, active = stop.visit, stop.active
        stop_id = stop.id
        routes.find(stop.route_id).move_stop_out(stop)
        route.add(visit, index || 1, { active: active || stop.route.vehicle_usage.nil? }, stop_id)
      elsif force && stop.is_a?(StopRest)
        active = stop.active
        stop_id = stop.id
        routes.find(stop.route_id).move_stop_out(stop, force)
        route.add_rest({ active: active }, stop_id)
      end
    else
      route.move_stop(stop, index || 1)
    end
  end

  # Available options:
  # out_of_zone (true by default)
  # active_only (true by default, only for prefered_route_and_index)
  # max_time
  # max_distance
  def automatic_insert(stop, options = { exclusion: :locked })
    options[:out_of_zone] = true if options[:out_of_zone] == nil

    available_routes = []

    # If already in route, stay in route
    if stop.route.vehicle_usage?
      available_routes = [stop.route]
    end

    # If zoning, get appropriate route
    if available_routes.empty?
      zone_route = get_associated_route_from_zones(stop.visit.destination, options)
      available_routes = [zone_route] if zone_route
    end

    # If still no route get all routes matching skills
    if available_routes.empty?
      tags = stop.is_a?(StopVisit) ? (stop.visit.destination.tags | stop.visit.tags) : nil
      skills_routes = get_routes_from_skills(tags, options)
      available_routes = skills_routes if skills_routes
    end

    # So, no target route, nothing to do
    if available_routes.empty?
      return
    end

    # Take the closest routes visit and eval insert
    route, index = prefered_route_and_index(available_routes, stop, options)
    if route
      stop.active = true
      move_stop(route, stop, index || 1)

      # FIXME: Moving rest inside its route might generate invalid stop index
      route.force_reindex if stop.is_a?(StopRest)
      return route
    end
  end

  def candidate_insert(destination, options = { exclusion: :locked })
    options[:out_of_zone] = true if options[:out_of_zone] == nil

    available_routes = []

    # If zoning, get appropriate route
    if available_routes.empty?
      zone_route = get_associated_route_from_zones(destination, options)
      available_routes = [zone_route] if zone_route
    end

    # If still no route get all routes matching skills
    if available_routes.empty?
      skills_routes = get_routes_from_skills(destination.tags, options)
      available_routes = skills_routes if skills_routes
    end

    # So, no target route, nothing to do
    if available_routes.empty?
      return
    end

    # Take the closest routes visit and eval insert
    prefered_route_data(available_routes, destination, options)
  end

  def get_associated_route_from_zones(destination, options = {})
    # If zoning, get appropriate route
    if zonings.any?
      # Directly assigning zones to a new zoning update their zoning_id
      collect_zones = zonings.collect{ |zoning| zoning.zones.map{ |z| z.dup }}.flatten
      zone = Zoning.new(zones: collect_zones).inside(destination)
      if zone && zone.vehicle
        route = get_routes_without_exclusion(options[:exclusion]).find{ |route|
          route.vehicle_usage? && route.vehicle_usage.vehicle == zone.vehicle
        }
        route
      end
    end
  end

  def get_routes_from_skills(tags, options = {})
    if options[:out_of_zone]
      skill_tags = all_skills & tags
      get_routes_without_exclusion(options[:exclusion]).select{ |route|
        next unless route.vehicle_usage?

        next true if skill_tags.empty?

        common_tags = [route.vehicle_usage.tags, route.vehicle_usage.vehicle.tags].flatten & tags
        !common_tags.empty?
      }
    end
  end

  def get_routes_without_exclusion(exclusion)
    case exclusion
    when :hidden
      routes.select{ |r| !r.hidden }
    when :locked
      routes.select{ |r| !r.locked }
    when :unavailable
      routes.select{ |r| !r.locked && !r.hidden}
    else
      routes
    end
  end

  def outdated
    routes.inject(false){ |acc, route|
      acc || route.outdated
    }
  end

  def tags_compatible?(tags_)
    if self.tag_operation == '_or'
      (tags_.to_a & tags.to_a).present?
    else
      (tags_.to_a & tags.to_a).size == tags.size
    end
  end

  def stores
    routes.flat_map{ |route|
      route.stops.only_stop_stores.map(&:store)
    }
  end

  def visits_compatibles
    plan_tags = tags.to_a
    return customer.visits if plan_tags.empty?

    if self.tag_operation == '_or'
      customer.visits.select { |visit|
        (plan_tags & (visit.tags.to_a | visit.destination.tags.to_a)).present?
      }
    else
      customer.visits.select { |visit|
        plan_tags & (visit.tags.to_a | visit.destination.tags.to_a) == plan_tags
      }
    end
  end

  def visits
    routes.flat_map{ |route|
      route.stops.only_stop_visits.includes_destinations.map(&:visit)
    }
  end

  def visits_to_stop_hash
    routes.flat_map{ |route|
      route.stops.only_stop_visits.includes_destinations.map{ |stop| [stop.visit.id, stop] }
    }.to_h
  end

  def relations
    plan_visits = visits.map(&:id)
    customer.stops_relations.select{ |r_f|
      plan_visits.include?(r_f.current_id) || plan_visits.include?(r_f.successor_id)
    }
  end

  def stops_relations
    return [] if customer.stops_relations.empty?

    stop_hash = visits_to_stop_hash
    relations.map{ |relation|
      {
        type: RELATION_KEYS[relation.relation_type.to_sym],
        linked_ids: [
          stop_hash[relation.current_id]&.id,
          stop_hash[relation.successor_id]&.id
        ].compact
      }
    }
  end

  def apply_orders(order_array, shift)
    orders = order_array.orders.select{ |order|
      order.shift == shift && !order.products.empty?
    }.collect{ |order|
      [order.visit_id, order.products]
    }
    orders = Hash[orders]

    routes.each{ |route|
      if route.vehicle_usage?
        route.stops.each{ |stop|
          stop.active = orders.key?(stop.visit_id) && !orders[stop.visit_id].empty?
        }
      end
      route.outdated = true
    }

    self.order_array = order_array
    self.date = order_array.base_date + shift
  end

  def split_by_zones(visits_free)
    self.zoning_outdated = false
    @zoning_ids_changed = false
    if !zonings.empty? && !routes.empty?
      # Make sure there is at least one Zone with Vehicle, else, don't apply Zones
      return unless zonings.any?{ |zoning| zoning.zones.any?{ |zone| !zone.avoid_zone && !zone.vehicle_id.blank? } }

      need_fetch_stop_status = routes.any?{ |r| r.stops.any?(&:status) }

      vehicles_map = Hash[routes.group_by(&:vehicle_usage).map { |vehicle_usage, routes|
        next if vehicle_usage && !vehicle_usage.active?
        [vehicle_usage && vehicle_usage.vehicle, routes[0]]
      }]

      # Get free visits if not the first initial split on planning building
      if !visits_free
        visits_free = routes.reject(&:locked).flat_map(&:stops).select{ |stop| stop.is_a?(StopVisit) }.map(&:visit)

        routes.each{ |route|
          route.locked || route.set_visits([])
        }
      end
        # Directly assigning zones to a new zoning updates their zoning_id
        collect_zones = zonings.collect{ |zoning| zoning.zones.map{ |z| z.dup }}.flatten
        Zoning.new(zones: collect_zones).apply(visits_free).each{ |zone, visits|
        if zone && zone.vehicle && vehicles_map[zone.vehicle] && !vehicles_map[zone.vehicle].locked
          vehicles_map[zone.vehicle].add_visits(visits.collect{ |d| [d, true] })
        else
          # Add to unplanned route even if the route is locked
          routes.find{ |r| !r.vehicle_usage? }.add_visits(visits.collect{ |d| [d, true] })
        end
      }

      fetch_stops_status if need_fetch_stop_status

      true
    end
  end

  def optimize(routes, **options, &optimizer)
    options = { global: false, active_only: true, ignore_overload_multipliers: [] }.merge(options)
    routes_with_vehicle = routes.select(&:vehicle_usage?)

    solution = optimizer.call(self, routes, options)

    routes_with_vehicle.each_with_index{ |r, i|
      r.optimized_at = Time.now.utc
      r.last_sent_to = r.last_sent_at = nil
    }
    solution
  end

  def outdate_drained_routes(route_ids)
    self.routes.where(id: route_ids).each{ |route|
      route.optimized_at = route.last_sent_to = route.last_sent_at = nil
      route.outdated = true
      route.save!
    }
  end

  def set_stops(optimum, **options)
    raise "Optimum and planning have no route in common #{self.routes.map(&:id)} & #{optimum.keys}" if (self.routes.map(&:id) & optimum.keys.compact).empty?

    Route.no_touching do
      Route.transaction do
        updated_route_ids = []
        stops_count = self.routes.collect{ |r| r.stops.size }.reduce(&:+)
        flat_stop_ids = optimum.values.flatten.compact
        out_stop_ids = optimum[nil] || optimum[self.routes.find{ |route| !route.vehicle_usage? }&.id] || []

        self.routes.each{ |route|
          next unless optimum.key?(route.id)

          stops_ = route.stops_segregate(**options) # Split stops according to stop active statement

          # Collect the stops assigned to the route
          ordered_stops = self.routes.flat_map{ |r| r.stops.select{ |s| optimum[route.id].include? s.id }}.sort_by { |s| optimum[route.id].index s.id }
          # Retrieve inactive stops provided by optimization
          deactivated_stops =
            if !options[:global] && route.vehicle_usage?
              route.stops.select{ |s| out_stop_ids.include? s.id }
            end || []
          # Retrieve inactive stops unused in optimization
          inactive_stops = stops_[false]&.reject{ |stop| flat_stop_ids.include?(stop.id) }&.sort_by(&:index) || []

          # Set route, active, index and reset route data
          i = 0
          ordered_stops.each{ |stop|
            if stop.is_a?(StopRest) && !route.vehicle_usage?
              flat_stop_ids.delete stop.id
            else
              if !options[:global] && !route.vehicle_usage? && route.id != stop.route_id
                stop.active = false;
                stop.index = i += 1
                stop.save!
                next
              end
              stop.active = true if route.vehicle_usage? && route.id != stop.route_id
              stop.index = i += 1
              stop.time = stop.distance = stop.drive_time = stop.out_of_window = stop.out_of_capacity = stop.out_of_drive_time = stop.out_of_work_time = stop.out_of_max_distance = stop.out_of_max_ride_distance = stop.out_of_max_ride_duration = nil
              if stop.route_id != route.id
                updated_route_ids << stop.route_id
                stop.route_id = route.id
              end
              stop.save!
            end
          }
          deactivated_stops.each{ |stop|
            stop.active = false if route.vehicle_usage?
            stop.index = i += 1
            stop.time = stop.distance = stop.drive_time = stop.out_of_window = stop.out_of_capacity = stop.out_of_drive_time = stop.out_of_work_time = stop.out_of_max_distance = stop.out_of_max_ride_distance = stop.out_of_max_ride_duration = nil
            if stop.route_id != route.id
              updated_route_ids << stop.route_id
              stop.route_id = route.id
            end
            stop.save!
          }
          inactive_stops.each{ |stop|
            stop.active = false if route.vehicle_usage?
            stop.index = i += 1
            stop.time = stop.distance = stop.drive_time = stop.out_of_window = stop.out_of_capacity = stop.out_of_drive_time = stop.out_of_work_time = stop.out_of_max_distance = stop.out_of_max_ride_distance = stop.out_of_max_ride_duration = nil
            stop.save!
          }
        }

        # Save route to update now stop.route_id
        self.routes.each{ |route|
          route.outdated = true
          (route.no_stop_index_validation = true) && route.save!
          route.stops.reload # Refresh route.stops collection if stops have been moved
        }
        updated_route_ids.uniq!
        outdate_drained_routes(updated_route_ids - self.routes.map(&:id)) if updated_route_ids.any?
        self.reload # Refresh route.stops collection if stops have been moved
        raise 'Invalid stops count' unless self.routes.collect{ |r| r.stops.size }.reduce(&:+) == stops_count
      end
    end
  end

  def fetch_stops_status
    Visit.transaction do
      if customer.enable_stop_status
        stops_map = Hash[routes.includes_destinations.available.where.not(vehicle_usage_id: nil).flat_map(&:stops).map { |stop| [(stop.is_a?(StopVisit) ? "v#{stop.visit_id}" : "r#{stop.id}"), stop] }]
        routes.each(&:clear_eta_data)
        routes_quantities_changed = []

        stops_status = Planner::Application.config.devices.each_pair.flat_map { |key, device|
          if device.respond_to?(:fetch_stops) && customer.device.configured?(key)
            device.fetch_stops(self.customer, device.planning_date(self), self) rescue nil
          end
        }.compact.select { |s|

          # Update ETA on Routes
          if !DeviceBase.is_a_store?(s[:order_id])
            true
          else
            if DeviceBase.is_fleet_hash?(s)
              attr = if DeviceBase.is_arrival?(s)
                {
                  arrival_eta: s[:eta],
                  arrival_status: s[:status]
                }
              else
                {
                  departure_eta: s[:eta],
                  departure_status: s[:status]
                }
              end
              route = routes.select { |r| r.id == s[:route_id].to_i }.first
              route && route.update(attr)
            end

            false
          end
        }.each { |s|
          if stops_map.key?(s[:order_id])
            # Specific to Praxedo
            if s[:update_quantities] && s[:deliveries].is_a?(Array)
              deliveries = {}
              du_by_label = {}
              customer.deliverable_units.map { |du| du_by_label[du.label] = du.id }
              s[:deliveries].map do |delivery|
                if du_by_label.keys.include?(delivery[:label])
                  value = Float(delivery[:delivery]) rescue nil
                  deliveries[du_by_label[delivery[:label]]] = value if value
                end
              end

              # Do not flag route as outdated just for quantities change, route quantities are computed after loop
              stops_map[s[:order_id]].visit.update(deliveries: deliveries, outdate_skip: true)
              routes_quantities_changed << stops_map[s[:order_id]].route
            end

            stops_map[s[:order_id]].update(status: s[:status], eta: s[:eta])
          end
        }

        routes_quantities_changed.each{ |route|
          route.compute_loads
          route.save
        }

        stops_status
      end
    end
  end

  def import_attributes
    self.attributes.except('lock_version')
  end

  def to_s
    "#{name}=>" + routes.collect(&:to_s).join(' ')
  end

  def large?
    routes.map{ |r| r.stops_size }.reduce(&:+) >= 1000
  end

  def to_geojson(include_stores = true, respect_hidden = true, include_linestrings = :polyline, with_quantities = false, large = large?)
    Route.routes_to_geojson(routes.includes_vehicle_usages, include_stores, respect_hidden, include_linestrings, with_quantities, large)
  end

  def save_import
    if valid? && !customer.too_many_plannings? && Planning.import([self], recursive: true, validate: false)
      Customer.reset_counters(customer.id, :plannings)
      # Import does not save has_and_belongs_to_many
      # So save it manually
      # https://github.com/zdennis/activerecord-import/pull/380
      t, z = self.tags, self.zonings
      self.reload
      self.tags, self.zonings = t, z
      # ActiveRecordImport doesn't call callbacks
      self.routes.each(&:complete_geojson)
      save
    end
  end

  def save_import!
    validate!
    raise(Exceptions::OverMaxLimitError.new(I18n.t('activerecord.errors.models.customer.attributes.plannings.over_max_limit'))) if customer.too_many_plannings?
    Planning.import([self], recursive: true, validate: false)
    Customer.reset_counters(customer.id, :plannings)

    # Import does not save has_and_belongs_to_many
    # So save it manually
    # https://github.com/zdennis/activerecord-import/pull/380
    t, z = self.tags, self.zonings
    self.reload
    self.tags, self.zonings = t, z
    # ActiveRecordImport doesn't call callbacks
    self.routes.each(&:complete_geojson)
    save!
  end

  def averages(metric)
    routes_distance = 0
    converter = metric == 'km' ? 3.6 : 2.237
    result = {
      routes_cost: nil,
      routes_revenue: nil,
      routes_emission: nil,
      routes_visits_duration: 0,
      routes_speed_average: 0,
      routes_drive_time: 0,
      routes_wait_time: 0,
      vehicles_used: 0,
      vehicles: 0
    }

    routes.each do |route|
      if route.vehicle_usage && !route.drive_time.nil?
        result[:routes_drive_time] += route.drive_time
        result[:vehicles_used] += 1 if route.drive_time > 0

        composed_cost = [route.cost_distance, route.cost_fixed, route.cost_time].compact.reduce(&:+)
        result[:routes_cost] =
          if result[:routes_cost].nil? || composed_cost.nil?
            composed_cost || result[:routes_cost]
          else
            result[:routes_cost] + composed_cost
          end
        result[:routes_revenue] = result[:routes_revenue].nil? ? route.revenue : result[:routes_revenue] + (route.revenue || 0)
        if route.emission
          result[:routes_emission] = 0 unless result[:routes_emission]
          result[:routes_emission] += route.emission
        end

        result[:routes_visits_duration] += route.visits_duration if route.visits_duration
        result[:routes_wait_time] += route.wait_time if route.wait_time

        routes_distance += route.distance
      end
      result[:vehicles] += 1 if route.vehicle_usage
    end

    if result[:routes_drive_time] != 0
      result[:routes_speed_average] = ((routes_distance / result[:routes_drive_time]) * converter).round
      result[:routes_wait_time] = result[:routes_wait_time] > 0 ? result[:routes_wait_time] : nil
      result[:routes_visits_duration] = result[:routes_visits_duration] > 0 ? result[:routes_visits_duration] : nil
    else
      result = nil
    end

    result
  end

  def all_skills
    routes.map do |r|
      next unless r.vehicle_usage
      [r.vehicle_usage.tags, r.vehicle_usage.vehicle.tags].flatten
    end.flatten.compact
  end

  def skills?
    all_skills.any?
  end

  def quantities
    Route.includes_deliverable_units.scoping do
      quantity_hash = {}
      units = self.customer.deliverable_units
      self.routes.each{ |route|
        vehicle = route.vehicle_usage.try(:vehicle)

        units.each{ |unit|
          pickup = route.pickups[unit.id].to_f
          delivery = route.deliveries[unit.id].to_f
          next if pickup == 0 && delivery == 0

          capacity = vehicle && vehicle.default_capacities[unit.id]
          if quantity_hash.key?(unit.id)
            quantity_hash[unit.id][:pickup] += pickup
            quantity_hash[unit.id][:delivery] += delivery
            quantity_hash[unit.id][:capacity] += capacity if capacity
          else
            quantity_hash[unit.id] = {
              id: unit.id,
              label: unit.label,
              unit_icon: unit.default_icon,
              pickup: pickup,
              delivery: delivery,
              capacity: capacity || 0,
              out_of_capacity:
                capacity && (pickup > capacity || delivery > capacity),
              has_pickup: pickup > 0,
              has_delivery: delivery > 0
            }
          end

          quantity_hash[unit.id][:out_of_capacity] = capacity && (pickup > capacity || delivery > capacity)
        }
      }

      quantity_hash.values.map { |quantity|
        quantity[:pickup] = LocalizedValues.localize_numeric_value(quantity[:pickup].round(2))
        quantity[:delivery] = LocalizedValues.localize_numeric_value(quantity[:delivery].round(2))
        # Nil if no capacity
        quantity[:capacity] = quantity[:capacity] > 0 ? LocalizedValues.localize_numeric_value(quantity[:capacity].round(2)) : nil
        quantity
      }
    end
  end

  private

  def select_insertion_data(insertion_data)
    insertion_by_route = insertion_data.group_by { |data| data[0] }
    selected_insertions = []

    # Select at least one insertion from each route
    insertion_by_route.each{ |route, insertions|
      best_insertion = insertions.min_by { |data| data[4] } # Sort by distance (data[2])
      selected_insertions << insertion_data.delete(best_insertion)
    }

    # Add the 20 first insertion_data
    selected_insertions += insertion_data.sort_by{ |data| data[4] }.first(20) if insertion_data.any?

    selected_insertions
  end

  def collect_insertion_data(route, stop, options = {})
    options[:active_only] = true if options[:active_only].nil?
    previous_position = route.vehicle_usage.default_store_start&.position || stop.position
    insertion_data = []
    route.stops.map{ |s|
      next if s.id == stop.id || !s.active && !options[:active_only] || !s.position?

      insertion_data <<
        [
          route,
          s.index - (stop.route == route && s.index > stop.index ? 1 : 0),
          segment = [
            [previous_position.lat, previous_position.lng, stop.position.lat, stop.position.lng],
            [stop.position.lat, stop.position.lng, s.position.lat, s.position.lng],
            [previous_position.lat, previous_position.lng, s.position.lat, s.position.lng]
          ],
          nil,
          previous_position.distance(stop.position) + stop.position.distance(s.position) - previous_position.distance(s.position)
        ]
      previous_position = s.position

    }
    next_position = route.vehicle_usage.default_store_stop&.position || stop.position
    insertion_data <<
      [
        route,
        route.stops.size + (stop.route == route ? 0 : 1),
        segment = [
          [previous_position.lat, previous_position.lng, stop.position.lat, stop.position.lng],
          [stop.position.lat, stop.position.lng, next_position.position.lat, next_position.position.lng],
          [previous_position.lat, previous_position.lng, next_position.position.lat, next_position.position.lng]
        ],
        nil,
        previous_position.distance(stop.position) + stop.position.distance(next_position) - previous_position.distance(next_position)
      ]

    insertion_data
  end

  def compute_detours(route, insertion_data)
    segments = insertion_data.flat_map{ |a|
      a[2]
    }
    vehicle = route.vehicle_usage.vehicle

    router_options = vehicle.default_router_options.symbolize_keys
    router_options[:geometry] = false
    router_options[:speed_multiplier] = vehicle.default_speed_multiplier

    traces =
      vehicle.default_router.trace_batch(segments, vehicle.default_router_dimension, router_options)

    # update the segments with the detour distance provided by the router
    insertion_data.each_index{ |index|
      insertion_data[index][2] = traces[3 * index][0] + traces[3 * index + 1][0] - traces[3 * index + 2][0]
      insertion_data[index][3] = traces[3 * index][1] + traces[3 * index + 1][1] - traces[3 * index + 2][1]
    }

    insertion_data
  end

  def prefered_route_and_index(available_routes, stop, options = {})
    min_detour = available_routes.flat_map { |route|
      route.compute # Update the eventual outdated route
      insertion_data = collect_insertion_data(route, stop, options)
      insertion_data = select_insertion_data(insertion_data)
      compute_detours(route, insertion_data)
    }.compact.select{ |a|
      insertion_available = true
      insertion_available = a[2] < options[:max_distance] if insertion_available && options[:max_distance]
      insertion_available = a[3] < options[:max_time] if insertion_available && options[:max_time]
      insertion_available
    }.min_by{ |a|
      a[3] #route time
    }
    return unless min_detour

    [min_detour[0], min_detour[1]]
  end

  def prefered_route_from_destination(available_routes, destination, options = {})
    options[:active_only] = true if options[:active_only].nil?

    # Create a temporary visit for the destination
    tmp_visit = Visit.new(destination_id: destination.id)
    tmp_stop = StopVisit.new(visit: tmp_visit)

    # Collect insertion data for all routes
    min_detour = available_routes.flat_map { |route|
      route.compute # Update the eventual outdated route
      insertion_data = collect_insertion_data(route, tmp_stop, options)
      compute_detours(route, insertion_data)
    }.compact.select{ |a|
      insertion_available = true
      insertion_available = a[2] < options[:max_distance] if insertion_available && options[:max_distance]
      insertion_available = a[3] < options[:max_time] if insertion_available && options[:max_time]
      insertion_available
    }.min_by{ |a|
      a[2]
    }
    return unless min_detour

    min_detour
  end

  def prefered_route_data(available_routes, destination, options = {})
    data = prefered_route_from_destination(available_routes, destination, options = {})

    {
      route: data[0],
      index: data[1],
      time: data[2]&.abs,
      distance: data[3]&.abs
    }
  end

  def update_routes_changed
    @routes_changed = true
  end

  def routes_changed?
    @routes_changed
  end

  def update_zonings_track(_zoning)
    @zoning_ids_changed = true
  end

  def zoning_ids_changed?
    @zoning_ids_changed
  end

  def update_tags_track(_tag)
    @tag_ids_changed = true
  end

  def tag_ids_changed?
    @tag_ids_changed
  end

  def update_zonings
    self.zoning_outdated = true if @zoning_ids_changed
  end

  def check_max_planning
    !self.customer.too_many_plannings? || raise(Exceptions::OverMaxLimitError.new(I18n.t('activerecord.errors.models.customer.attributes.plannings.over_max_limit')))
  end

  def unlink_job_optimizer
    customer.job_optimizer.destroy if Job.on_planning(customer.job_optimizer, id)
  end

  def update_vehicle_usage_set
    if vehicle_usage_set_id_changed? && !vehicle_usage_set_id_was.nil? && !id.nil?
      h = Hash[routes.select(&:vehicle_usage).collect{ |route| [route.vehicle_usage.vehicle, route] }]
      vehicle_usage_set.vehicle_usages.each{ |vehicle_usage|
        if h[vehicle_usage.vehicle] && vehicle_usage.active
          h[vehicle_usage.vehicle].vehicle_usage = vehicle_usage
          h[vehicle_usage.vehicle].save!
        elsif vehicle_usage.active
          vehicle_usage_add vehicle_usage
        elsif h[vehicle_usage.vehicle]
          vehicle_usage_remove h[vehicle_usage.vehicle].vehicle_usage
        end
      }
      compute
    end
  end

  def begin_after_end_date
    if self.begin_date.present? && self.end_date.present? && self.end_date < self.begin_date
      errors.add(:end_date, I18n.t('activerecord.errors.models.planning.attributes.end_date.after'))
    end
  end
end
