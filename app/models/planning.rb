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

  belongs_to :customer
  has_and_belongs_to_many :zonings, autosave: true, after_add: :update_zonings_track, after_remove: :update_zonings_track
  has_many :routes, -> { order(Arel.sql('CASE WHEN vehicle_usage_id IS NULL THEN 0 ELSE routes.id END')) }, inverse_of: :planning, autosave: true, dependent: :delete_all

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
  validate :valid_date?
  validate :begin_after_end_date

  include Consistency
  validate_consistency :vehicle_usage_set, :order_array, :zonings, :tags

  before_create :update_zonings, :check_max_planning
  before_destroy :unlink_job_optimizer
  before_save :update_vehicle_usage_set

  include RefSanitizer

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
    copy.name += " (#{I18n.l(Time.zone.now, format: :long)})"
    copy
  end

  def changed?
    routes_changed? || super
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
        routes[i].set_visits(r[:visits].select{ |visit|
          tags_compatible?(visit[0].tags.to_a | visit[0].destination.tags.to_a)
        }, recompute, ignore_errors)
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
      r.preload_compute_scopes if r.outdated
      r.compute(options)
    }
  end

  def compute_saved(options = {})
    routes.find_in_batches(batch_size: 10){ |group|
      group.each{ |r|
        # Load necessary scopes just in time for outdated routes
        r.preload_compute_scopes
        r.compute(options)
        r.save
      }
      self.save! && self.reload
    }
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
      stop = route.stops.where(visit_id: visit.id, type: 'StopVisit').first
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
        stop.route.move_stop_out(stop)
        route.add(visit, index || 1, active || stop.route.vehicle_usage.nil?, stop_id)
      elsif force && stop.is_a?(StopRest)
        active = stop.active
        stop_id = stop.id
        stop.route.move_stop_out(stop, force)
        route.add_rest(active, stop_id)
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
  def automatic_insert(stop, options = {})
    options[:out_of_zone] = true if options[:out_of_zone] == nil

    available_routes = []

    # If already in route, stay in route
    if stop.route.vehicle_usage?
      available_routes = [stop.route]
    end

    # If zoning, get appropriate route
    if available_routes.empty?
      zone_route = get_associated_route_from_zones(stop.visit.destination)
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
      return route
    end
  end

  def candidate_insert(destination, options = {})
    options[:out_of_zone] = true if options[:out_of_zone] == nil

    available_routes = []

    # If zoning, get appropriate route
    if available_routes.empty?
      zone_route = get_associated_route_from_zones(destination)
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

  def get_associated_route_from_zones(destination)
    # If zoning, get appropriate route
    if zonings.any?
      zone = Zoning.new(zones: zonings.collect(&:zones).flatten).inside(destination)
      if zone && zone.vehicle
        route = routes.find{ |route|
          route.vehicle_usage? && route.vehicle_usage.vehicle == zone.vehicle && !route.locked
        }
        route
      end
    end
  end

  def get_routes_from_skills(tags, options = {})
    if options[:out_of_zone]
      skill_tags = all_skills & tags
      routes.select{ |route|
        next unless route.vehicle_usage?

        if skill_tags.any?
          common_tags = [route.vehicle_usage.tags, route.vehicle_usage.vehicle.tags].flatten & tags
          !route.locked && !common_tags.empty?
        else
          !route.locked
        end
      }
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
      route.stops.only_stop_visits.map(&:visit)
    }
  end

  def visits_to_stop_hash
    routes.flat_map{ |route|
      route.stops.only_stop_visits.map{ |stop| [stop.visit.id, stop] }
    }.to_h
  end

  def relations
    plan_visits = visits.map(&:id)
    customer.relations.select{ |r_f|
      plan_visits.include?(r_f.current_id) || plan_visits.include?(r_f.successor_id)
    }
  end

  def stop_relations
    return [] if customer.relations.empty?

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

      Zoning.new(zones: zonings.collect(&:zones).flatten).apply(visits_free).each{ |zone, visits|
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

  def optimize(routes, options, &optimizer)
    options = { global: false, active_only: true, ignore_overload_multipliers: [] }.merge(options)
    routes_with_vehicle = routes.select(&:vehicle_usage?)

    solution = optimizer.call(self, routes, options)

    routes_with_vehicle.each_with_index{ |r, i|
      r.optimized_at = Time.now.utc
      r.last_sent_to = r.last_sent_at = nil
    }
    solution
  end

  def set_stops(routes, stop_ids, options = {})
    options = { global: false, active_only: true }.merge(options)
    raise 'Invalid routes count' if routes.size != stop_ids.size && !options[:insertion_only]

    Route.transaction do
      stops_count = routes.collect{ |r| r.stops.size }.reduce(&:+)
      flat_stop_ids = stop_ids.flatten.compact
      inactive_stop_ids = []

      routes.select(&:vehicle_usage?).each do |route|
        inactive_stop_ids += route.stops.reject(&:active).map(&:id)
      end

      routes.each_with_index{ |route, index|
        stops_ = route.stops_segregate(options[:active_only]) # Split stops according to stop active statement

        # Fetch sorted stops returned by optim from all routes
        # index dependent: route[0] == stop_ids[0]
        ordered_stops = routes.flat_map{ |r| r.stops.select{ |s| stop_ids[index].include? s.id }}.sort_by { |s| stop_ids[index].index s.id }

        # 1. Set route and index (active stops returned by optim for instance)
        i = 0
        ordered_stops.each{ |stop|
          # Don't change route for rests, but build index
          if stop.is_a?(StopRest) && !route.vehicle_usage?
            flat_stop_ids.delete stop.id
          else

            # 'Optim. each', actual route contains unplanned and stop asigned to other route, then set stop to unactive
            if !options[:global] && !route.vehicle_usage? && index == 0 && route.id != stop.route_id
              stop.active = false;
              stop.index = i += 1
              stop.save!
              next
            end

            stop.active = true if route.vehicle_usage? && inactive_stop_ids.exclude?(stop.id)
            stop.index = i += 1
            stop.time = stop.distance = stop.drive_time = stop.out_of_window = stop.out_of_capacity = stop.out_of_drive_time = stop.out_of_work_time = stop.out_of_max_distance = stop.out_of_max_ride_distance = stop.out_of_max_ride_duration = nil
            if stop.route_id != route.id
              stop.route_id = route.id
              stop.save!
            end
          end
        }

        # 2. Set index and active for other stops (inactive or not in optim for instance)
        other_inactive_stops = (stops_[true] ? stops_[true].select{ |s| s.route_id == route.id && flat_stop_ids.exclude?(s.id) }.sort_by(&:index) : []) - ordered_stops + (stops_[false] ? stops_[false].sort_by(&:index) : [])
        other_inactive_stops.each{ |stop|
          stop.active = false if route.vehicle_usage?
          stop.index = i += 1
          stop.time = stop.distance = stop.drive_time = stop.out_of_window = stop.out_of_capacity = stop.out_of_drive_time = stop.out_of_work_time = stop.out_of_max_distance = stop.out_of_max_ride_distance = stop.out_of_max_ride_duration = nil
        }
      }

      # Save route to update now stop.route_id
      routes.each{ |route|
        route.outdated = true
        (route.no_stop_index_validation = true) && route.save!
        route.stops.reload # Refresh route.stops collection if stops have been moved
      }
      raise 'Invalid stops count' unless routes.collect{ |r| r.stops.size }.reduce(&:+) == stops_count

      self.reload # Refresh route.stops collection if stops have been moved
    end
  end

  def fetch_stops_status
    Visit.transaction do
      if customer.enable_stop_status
        stops_map = Hash[routes.select(&:vehicle_usage?).flat_map(&:stops).map { |stop| [(stop.is_a?(StopVisit) ? "v#{stop.visit_id}" : "r#{stop.id}"), stop] }]
        routes.each(&:clear_eta_data)
        routes_quantities_changed = []

        stops_status = Mapotempo::Application.config.devices.each_pair.flat_map { |key, device|
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
              route && route.assign_attributes(attr)
            end

            false
          end
        }.each { |s|
          if stops_map.key?(s[:order_id])
            # Specific to Praxedo
            if s[:update_quantities] && s[:quantities].is_a?(Array)
              quantities = {}
              du_by_label = {}
              customer.deliverable_units.map { |du| du_by_label[du.label] = du.id }
              s[:quantities].map do |quantity|
                if du_by_label.keys.include?(quantity[:label])
                  value = Float(quantity[:quantity]) rescue nil
                  quantities[du_by_label[quantity[:label]]] = value if value
                end
              end

              Visit.without_callback(:update, :before, :update_outdated) do
                # Do not flag route as outdated just for quantities change, route quantities are computed after loop
                stops_map[s[:order_id]].visit.update_attributes(quantities: quantities)
              end
              routes_quantities_changed << stops_map[s[:order_id]].route
            end

            stops_map[s[:order_id]].assign_attributes(status: s[:status], eta: s[:eta])
          end
        }

        routes_quantities_changed.each(&:compute_quantities)

        stops_status
      end
    end
  end

  def to_s
    "#{name}=>" + routes.collect(&:to_s).join(' ')
  end

  def large?
    routes.map{ |r| r.stops.size }.reduce(&:+) >= 1000
  end

  def to_geojson(include_stores = true, respect_hidden = true, include_linestrings = :polyline, with_quantities = false, large = large?)
    Route.routes_to_geojson(routes.includes_vehicle_usages, include_stores, respect_hidden, include_linestrings, with_quantities, large)
  end

  def save_import
    if valid? && !customer.too_many_plannings? && Planning.import([self], recursive: true, validate: false)
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
      hashy_map = {}
      self.routes.each do |route|
        vehicle = route.vehicle_usage.try(:vehicle)

        route.quantities.select{ |_k, v| v > 0 }.each do |id, v|
          unit = route.planning.customer.deliverable_units.find{ |du| du.id == id }
          next unless unit && vehicle

          capacity = vehicle && vehicle.default_capacities[id]
          if hashy_map.key?(unit.id)
            hashy_map[unit.id][:quantity] += v
            hashy_map[unit.id][:capacity] += capacity || 0
            hashy_map[unit.id][:out_of_capacity] = capacity && (hashy_map[unit.id][:quantity] > hashy_map[unit.id][:capacity])
          else
            hashy_map[unit.id] = {
              id: unit.id,
              label: unit.label,
              unit_icon: unit.default_icon,
              quantity: v,
              capacity: capacity || 0,
              out_of_capacity: capacity && (v > capacity)
            }
          end
        end
      end

      hashy_map.to_a.map { |unit|
        unit[1][:quantity] = LocalizedValues.localize_numeric_value(unit[1][:quantity].round(2))
        # Nil if no capacity
        unit[1][:capacity] = unit[1][:capacity] > 0 ? LocalizedValues.localize_numeric_value(unit[1][:capacity].round(2)) : nil
        unit[1]
      }
    end
  end

  private

  def prefered_route_and_index(available_routes, stop, options = {})
    options[:active_only] = true if options[:active_only].nil?
    cache_sum_out_of_window = Hash.new{ |h, k| h[k] = k.sum_out_of_window }
    tmp_routes = {}

    by_distance = available_routes.flat_map { |route|
      stops =
      if options[:active_only]
        route.stops.where(type: StopVisit.name).where(active: true).joins(:visit).merge(Visit.positioned)
      else
        route.stops.where(type: StopVisit.name).joins(:visit).merge(Visit.positioned)
      end
      stops = stops.map { |s| [s.visit.destination, route, s.index] }
      stops ||= []
      stops << [route.vehicle_usage.default_store_start, route, 1] if stops.empty? && route.vehicle_usage.default_store_start&.position?
      stops << [route.vehicle_usage.default_store_stop, route, route.stops.size + 1] if route.vehicle_usage&.default_store_stop&.position?
      stops
    }.compact.sort_by{ |a|
      a[0] && a[0].position? ? a[0].distance(stop.position) : Float::INFINITY
    }
    return available_routes.first if by_distance.empty?

    # If more than one available_routes take at least one stop from second route
    pos_second_route = by_distance.index{ |s| s[1].id != by_distance[0][1].id } if available_routes.size > 1
    # Take 5% from nearest stops (min: 3, max: 10) and a stop in second route if it exists
    (by_distance[0..[9, [2, by_distance.size / 20].max].min] +
      (pos_second_route ? [by_distance[pos_second_route]] : [])).flat_map{ |dest_route_idx|
      [[dest_route_idx[1], dest_route_idx[2]], [dest_route_idx[1], dest_route_idx[2] + 1]]
    }.uniq.map { |ri|
      ri[0].class.amoeba do
        clone :stops # Only duplicate stops just for compute evaluation
        nullify :planning_id
      end

      tmp_routes[ri[0].id] = ri[0].amoeba_dup if !tmp_routes[ri[0].id]
      r = tmp_routes[ri[0].id]
      if stop.is_a?(StopVisit)
        r.add(stop.visit, ri[1], true)
      else
        r.add_or_update_rest(true)
      end
      r.compute(no_geojson: true, no_quantities: true)

      # Difference of total time + difference of sum of out_of_window time
      ri[2] = ((r.end - r.start) - (ri[0].end && ri[0].start ? ri[0].end - ri[0].start : 0)) + (r.sum_out_of_window - cache_sum_out_of_window[ri[0]])
      # Delta distance
      ri[3] = r.distance - ri[0].distance.to_f

      r.remove_visit(stop.visit) if stop.is_a?(StopVisit)

      # Return ri with time and distance added
      ri
    }.select { |ri|
      # Check for max time or distance if any
      route_available = true
      route_available = ri[2].abs < options[:max_time] if options[:max_time] && route_available
      route_available = ri[3].abs < options[:max_distance] if options[:max_distance] && route_available
      route_available
    }.min_by { |ri|
      # Return route with the minimum time
      ri[2]
    }
  end

  def prefered_route_from_destination(available_routes, destination, options = {})
    options[:active_only] = true if options[:active_only].nil?
    cache_sum_out_of_window = Hash.new{ |h, k| h[k] = k.sum_out_of_window }
    tmp_routes = {}

    by_distance = available_routes.flat_map { |route|
      stops =
      if options[:active_only]
        route.stops.where(type: StopVisit.name).where(active: true).joins(:visit).merge(Visit.positioned)
      else
        route.stops.where(type: StopVisit.name).joins(:visit).merge(Visit.positioned)
      end
      stops = stops.map { |s| [s.visit.destination, route, s.index] }
      stops ||= []
      stops << [route.vehicle_usage.default_store_start, route, 1] if stops.empty? && route.vehicle_usage.default_store_start&.position?
      stops << [route.vehicle_usage.default_store_stop, route, route.stops.size + 1] if route.vehicle_usage&.default_store_stop&.position?
      stops
    }.compact.sort_by{ |a|
      a[0] && a[0].position? ? a[0].distance(destination) : Float::INFINITY
    }
    return available_routes.first if by_distance.empty?

    tmp_visit = Visit.new(destination_id: destination.id)
    # If more than one available_routes take at least one stop from second route
    pos_second_route = by_distance.index{ |s| s[1].id != by_distance[0][1].id } if available_routes.size > 1
    # Take 5% from nearest stops (min: 3, max: 10) and a stop in second route if it exists
    (by_distance[0..[9, [2, by_distance.size / 20].max].min] +
      (pos_second_route ? [by_distance[pos_second_route]] : [])).flat_map{ |dest_route_idx|
      [[dest_route_idx[1], dest_route_idx[2]], [dest_route_idx[1], dest_route_idx[2] + 1]]
    }.uniq.map { |ri|
      ri[0].class.amoeba do
        clone :stops # Only duplicate stops just for compute evaluation
        nullify :planning_id
      end

      tmp_routes[ri[0].id] = ri[0].amoeba_dup if !tmp_routes[ri[0].id]
      r = tmp_routes[ri[0].id]
      r.add(tmp_visit, ri[1], true)
      r.compute(no_geojson: true, no_quantities: true)

      # Difference of total time + difference of sum of out_of_window time
      ri[2] = ((r.end - r.start) - (ri[0].end && ri[0].start ? ri[0].end - ri[0].start : 0)) + (r.sum_out_of_window - cache_sum_out_of_window[ri[0]])
      # Delta distance
      ri[3] = r.distance - ri[0].distance.to_f

      r.remove_visit(tmp_visit)

      # Return ri with time and distance added
      ri
    }.select { |ri|
      # Check for max time or distance if any
      route_available = true
      route_available = ri[2].abs < options[:max_time] if options[:max_time] && route_available
      route_available = ri[3].abs < options[:max_distance] if options[:max_distance] && route_available
      route_available
    }.min_by { |ri|
      # Return route with the minimum time
      ri[2]
    }
  end

  def prefered_route_data(available_routes, destination, options = {})
    data = prefered_route_from_destination(available_routes, destination, options = {})

    {
      route: data[0],
      index: data[1],
      time: data[2].abs,
      distance: data[3].abs
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
      h = Hash[routes.includes_vehicle_usages.select(&:vehicle_usage).collect{ |route| [route.vehicle_usage.vehicle, route] }]
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

  def valid_date?
    return true if self.date.nil?

    Date.parse(self.date.to_s)
  rescue ArgumentError
    errors.add(:date, I18n.t('activerecord.errors.models.planning.attributes.date.invalid'))
  end
end
