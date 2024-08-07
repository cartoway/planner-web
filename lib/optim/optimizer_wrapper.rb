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
require 'rest_client'

class VRPNoSolutionError < StandardError; end
class VRPUnprocessableError < StandardError; end

PROGRESSION_KEYS = ['split independent process', 'solution', 'repetition', 'split partition process', 'max split process', 'dichotomous process']

class OptimizerWrapper

  attr_accessor :cache, :url, :api_key

  POSITION_KEYS = { always_first: :force_first, always_final: :force_end, never_first: :never_first}.freeze

  def initialize(cache, url, api_key)
    @cache, @url, @api_key = cache, url, api_key
  end

  def kill_solve(job_id)
    return unless job_id

    RestClient.delete(@url + "/vrp/jobs/#{job_id}.json", params: {api_key: @api_key})
  rescue RestClient::NotFound
    true
  rescue RestClient::MovedPermanently, RestClient::Found, RestClient::TemporaryRedirect => e
    e.response.follow_redirection
    false
  end

  def build_vrp(planning, routes, options = {})
    vrp_vehicles, v_points = build_vehicles(planning, routes, options)
    all_skills = vrp_vehicles.map { |v| v[:skills] }.flatten.compact

    stops = routes.flat_map{ |route|
      next [] if route.vehicle_usage.nil? && !options[:global]

      route.stops
    }
    stops += Stop.where(id: options[:moving_stop_ids])
    stops.uniq!

    vrp_services, s_points = build_services(planning, stops, options.merge(use_skills: all_skills.any?, problem_skills: all_skills))
    vrp_rests = build_rests(stops, options)
    relations = collect_relations(routes, options)

    vrp_routes = build_routes(routes, options) if options[:only_insertion]
    vrp_units = vrp_vehicles.flat_map{ |v| v[:capacities]&.map{ |c| c[:unit_id] } }.compact.uniq.map{ |unit_id|
      { id: unit_id }
    }

    vrp = {
      configuration: build_configuration(options.merge(service_count: vrp_services.size, vehicle_count: vrp_vehicles.size)),
      name: options[:name],
      points: v_points + s_points,
      relations: relations,
      rests: vrp_rests,
      routes: vrp_routes,
      services: vrp_services,
      units: vrp_units,
      vehicles: vrp_vehicles
    }
    filter_constraints(routes, vrp, options)
    vrp
  end

  def optimize(planning, routes, options = {}, &progress)
    vrp = build_vrp(planning, routes, options)
    key = Digest::MD5.hexdigest(Marshal.dump(vrp))

    result = @cache.read(key)
    if result
      result = JSON.parse(result)
    else
      result = solve(vrp, progress, key)
    end

    optimum = [result['solutions'][0]['unassigned'] ? result['solutions'][0]['unassigned'].select{ |activity| activity['service_id'] }.collect{ |activity|
      activity['service_id'][1..-1].to_i
    } : []] + vrp[:vehicles].collect{ |vehicle|
      route = result['solutions'][0]['routes'].find{ |r| r['vehicle_id'] == vehicle[:id] }
      !route ? [] : route['activities'].collect{ |activity|
        if activity.key?('service_id')
          activity['service_id'][1..-1].to_i
        elsif activity.key?('rest_id')
          activity['rest_id'][1..-1].to_i
        end
      }.compact # stores are not returned anymore
    }
    optimum = optimum[1..-1] if routes.none?{ |route| !route.vehicle_usage? }
    if @removed_route_indices&.any?
      @removed_route_indices.each{ |index| optimum.insert(index, [])}
    end
    optimum
  end

  def solve(vrp, progress, key)
    resource_vrp = RestClient::Resource.new(@url + '/vrp/submit.json', timeout: nil)
    json = resource_vrp.post({api_key: @api_key, vrp: vrp}.to_json, content_type: :json, accept: :json) { |response, request, result, &block|
      if response.code != 200 && response.code != 201
        json = (response && /json/.match(response.headers[:content_type]) && response.size > 1) ? JSON.parse(response) : nil
        msg = if json && json['message']
                json['message']
              elsif json && json['error']
                json['error']
              end
        Delayed::Worker.logger.info "VRP submit #{response.code} " + (msg || '') + ' ' + request.to_json
        raise VRPUnprocessableError, msg || 'Unexpected error'
      end
      response
    }

    result = nil
    while json
      retry_counter = 0
      result = JSON.parse(json)
      job_details = result['job']
      job_id = result.dig('job', 'id')
      if result.dig('job', 'status') == 'completed'
        @cache.write(key, json.body)
        break
      elsif ['queued', 'working'].include?(result.dig('job', 'status'))
        begin
          if progress && job_details
            solution_data = compute_progression(vrp, result, job_details)
            progress.call(job_id, solution_data)
          end
          sleep(0.2)
          json = RestClient.get(@url + "/vrp/jobs/#{job_id}.json", params: {api_key: @api_key})
        rescue SocketError => e
          retry_counter += 1
          retry if retry_counter < 3

          raise e
        rescue Delayed::WorkerTimeout
          kill_solve(job_id)
          raise JobTimeout.new("Optimizer Job #{job_id} has reached max_run_time: #{ScheduleType.new.type_cast(Delayed::Worker.max_run_time)}")
        end
      else
        if /No solution provided/.match result.dig('job', 'avancement')
          raise VRPNoSolutionError.new
        else
          raise RuntimeError.new(result.dig('job', 'avancement') || 'Optimizer return unknown error')
        end
      end
    end
    result
  end

  private

  def build_configuration(options)
    service_ratio = options[:moving_stop_ids]&.any? ? options[:moving_stop_ids].size.to_f / options[:service_count] : 1
    optim_duration_min = if options[:optimize_minimal_time]
      (service_ratio * options[:optimize_minimal_time] * options[:vehicle_count] * 1000).to_i
    end
    optim_duration_max = if options[:optimize_time]
      (service_ratio * options[:optimize_time] * options[:vehicle_count] * options[:service_count]).to_i
    end
    {
      preprocessing: {
        max_split_size: options[:max_split_size],
        cluster_threshold: options[:cluster_threshold],
        prefer_short_segment: true,
        first_solution_strategy: :self_selection,
      },
      resolution: {
        duration: optim_duration_max,
        initial_time_out: optim_duration_min,
        time_out_multiplier: 2
      },
      restitution: {
        intermediate_solutions: false
      }
    }
  end

  def build_point(stop, options = {})
    position_label = stop.position.is_a?(Destination) ? 'p' : 'd'
    {
      id: "#{position_label}#{stop.position.id}",
      location: {
        lat: stop.position.lat,
        lon: stop.position.lng
      }
    }
  end

  # A StopRest with a position is send as a service
  def build_rests(stops, options = {})
    stops.map{ |stop|
      next unless stop.is_a?(StopRest) && stop.destination.lat

      {
        id: "r#{stop.id}",
        timewindows: [{
          start: stop.time_window_start_1.try(:to_f),
          end: stop.time_window_end_1.try(:to_f)
        }],
        duration: stop.duration
      }
    }.compact
  end

  def build_routes(routes, options = {})
    routes.map{ |route|
      next if route.vehicle_usage.nil?

      mission_ids = route.stops.map{ |stop|
        next if stop.is_a?(StopRest) && !stop.position? ||
                !stop.active && options[:only_active] ||
                options[:moving_stop_ids]&.include?(stop.id)

        "s#{stop.id}"
      }.compact

      next if mission_ids.empty?
      {
        vehicle_id: "v#{route.vehicle_usage_id}",
        mission_ids: mission_ids
      }
    }.compact
  end

  def build_services(planning, stops, options = {})
    point_hash = {}
    services_late_multiplier = (options[:stop_soft_upper_bound] && options[:stop_soft_upper_bound] > 0) ? options[:stop_soft_upper_bound] : nil
    vrp_services = stops.map{ |stop|
      next if options[:only_active] && !stop.active

      service_point = build_point(stop)
      # A stop without destination is either a proper rest either cannot be send to the optimizer
      next if service_point.nil?

      point_hash[service_point[:id]] = service_point

      tags_label = stop.is_a?(StopVisit) ? (stop.visit.destination.tags | stop.visit.tags).map(&:label) & planning.all_skills.map(&:label) : nil
      {
        id: "s#{stop.id}",
        type: 'service',
        sticky_vehicle_ids:
          stop.route.vehicle_usage_id &&
          (!options[:global] || stop.is_a?(StopRest)) &&
          (options[:moving_stop_ids].nil? || options[:moving_stop_ids].exclude?(stop.id)) ? ["v#{stop.route.vehicle_usage_id}"] : nil, # to force an activity on a vehicle (for instance geoloc rests)
        activity: {
          point_id: service_point[:id],
          timewindows: [
            (stop.time_window_start_1 || stop.time_window_end_1) && {
              start: stop.time_window_start_1.try(:to_f),
              end: stop.time_window_end_1.try(:to_f)
            },
            (stop.time_window_start_2 || stop.time_window_end_2) && {
              start: stop.time_window_start_2.try(:to_f),
              end: stop.time_window_end_2.try(:to_f)
            },
          ].compact,
          duration: stop.duration,
          late_multiplier: services_late_multiplier
        }.delete_if{ |_k, v| v.nil? || v.respond_to?(:empty?) && v.empty? },
        priority: stop.priority && (stop.priority.to_i - 4).abs,
        quantities: stop.visit.default_quantities&.map{ |k, v|
          v ? {
            unit_id: "u#{k}",
            value: v,
            fill: stop.visit.quantities_operations[k] == 'fill' || nil,
            empty: stop.visit.quantities_operations[k] == 'empty' || nil
          }.compact : nil
        }&.compact || [],
        skills: (options[:use_skills] && tags_label) ? (options[:problem_skills] & tags_label) : nil
      }.delete_if{ |_k, v| v.nil? || v.respond_to?(:empty?) && v.empty? }
    }
    [vrp_services, point_hash.values]
  end

  def build_vehicles(planning, routes, options)
    vehicles_cost_late_multiplier = (options[:vehicle_soft_upper_bound] && options[:vehicle_soft_upper_bound] > 0) ? options[:vehicle_soft_upper_bound] : nil

    vrp_vehicles = []
    point_hash = {}

    routes.each{ |route|
      next if route.vehicle_usage.nil?

      %i(start stop).each{ |store_type|
        type_label = "store_#{store_type}"
        next if route.vehicle_usage.send(type_label).nil?

        type_id_label = "store_#{store_type}_id"
        if route.vehicle_usage.send(type_label).lat && route.vehicle_usage.send(type_label).lng
          label = "d#{route.vehicle_usage.send(type_id_label)}"
          point_hash[label] = {
            id: label,
            location: {
              lat: route.vehicle_usage.send(type_label).lat,
              lon: route.vehicle_usage.send(type_label).lng
            }
          }
        end
      }

      vehicle = route.vehicle_usage.vehicle
      vehicle_skills = [route.vehicle_usage.tags, route.vehicle_usage.vehicle.tags].flatten.compact.uniq.map(&:label)

      # Only register as rest StopRests without destination
      vehicle_rests = route.stops.select{ |stop| stop.is_a?(StopRest) && !stop.position? }
      capacities = vehicle.default_capacities&.map{ |k, v|
        next if v.nil?

        strict_capacity = options[:ignore_overload_multipliers].find{ |iom| iom[:unit_id] == k } if options[:ignore_overload_multipliers]
        ignore_capacity = options[:ignore].find{ |iom| iom[:unit_id] == k } if options[:ignore]
        {
          unit_id: "u#{k}",
          limit: ignore_capacity ? nil : v,
          overload_multiplier: strict_capacity ? nil : (planning.customer.deliverable_units.find{ |du| du.id == k }.optimization_overload_multiplier || Mapotempo::Application.config.optimize_overload_multiplier)
        }
      }&.compact

        vrp_vehicles << {
          id: "v#{route.vehicle_usage_id}",
          router_mode: route.vehicle_usage.vehicle.default_router.try(&:mode),
          router_dimension: route.vehicle_usage.vehicle.default_router_dimension,
          router_options: route.vehicle_usage.vehicle.default_router_options
                               .symbolize_keys.except(:time, :distance, :isochrone, :isodistance, :avoid_zones)
                               .delete_if{ |k, v| v.nil? } || {},
          speed_multiplier: route.vehicle_usage.vehicle.default_speed_multiplier,
          area: Zoning.speed_multiplier_areas(planning.zonings)&.map{ |a| a[:area].join(',') }&.join('|'),
          speed_multiplier_area: Zoning.speed_multiplier_areas(planning.zonings)&.map{ |a| a[:speed_multiplier_area] }&.join('|'),
          timewindow: { start: vehicle[:open], end: vehicle[:close] }.delete_if{ |_k, v| v.nil? },
          duration: route.vehicle_usage.default_work_time(true)&.to_f,
          distance: route.vehicle_usage.vehicle.max_distance,
          maximum_ride_distance: route.vehicle_usage.vehicle.max_ride_distance,
          maximum_ride_time: route.vehicle_usage.vehicle.max_ride_duration,
          start_point_id: route.vehicle_usage.store_start_id && "d#{route.vehicle_usage.store_start_id}",
          end_point_id: route.vehicle_usage.store_start_id && "d#{route.vehicle_usage.store_start_id}",
          cost_fixed: 0,
          cost_distance_multiplier: route.vehicle_usage.vehicle.default_router_dimension == 'distance' ? 1 : 0,
          cost_time_multiplier: route.vehicle_usage.vehicle.default_router_dimension == 'time' ? 1 : 0,
          cost_waiting_time_multiplier: route.vehicle_usage.vehicle.default_router_dimension == 'time' ? options[:optimization_cost_waiting_time] : 0,
          cost_late_multiplier: vehicles_cost_late_multiplier,
          shift_preference: (route.force_start || options[:force_start]) ? 'force_start' : nil,
          rest_ids: vehicle_rests.map{ |r| "r#{r[:id]}" },
          capacities: capacities || [],
          skills: [vehicle_skills]
      }.delete_if{ |_k, v| v.nil? || v.respond_to?(:empty?) && v.empty? }
    }

    [vrp_vehicles, point_hash.values]
  end

  def collect_relations(routes, options)
    return route_orders(routes, options) if options[:only_insertion]

    stops = routes.flat_map{ |route|
      next [] if route.vehicle_usage.nil? && !options[:global]

      route.stops
    }
    relations = []
    relations += filter_option_relations(stops, options)
    relations += position_relations(stops)
    relations += negative_quantities_relations(stops)
    relations
  end

  def filter_constraints(routes, vrp, options = {})
    if options[:only_insertion]
      only_insertion_services(vrp[:services])
      only_insertion_vehicles(routes, vrp)
      vrp[:rests] = []
    end
  end

  def filter_option_relations(stops, options)
    return [] unless options[:relations]

    stop_hash = stops.map{ |s| [s.id, s] }.to_h

    options[:relations].delete_if{ |relation|
      relation[:linked_ids].any?{ |id| !stop_hash.key?(id) }
    }
    options[:relations].each{ |relation|
      relation[:linked_ids].map!{ |id| "s#{id}"}
    }
    options[:relations]
  end

  def position_relations(stops)
    relations = []
    stops.select{ |stop| stop.is_a?(StopVisit) }
         .group_by{ |stop| stop.visit.force_position }
         .each{ |position, stps|
           next if position.nil? || position == 'neutral'

           relations << {
             type: POSITION_KEYS[position.to_sym],
             linked_ids: stps.map{ |stop| "s#{stop.id}" }}
         }
    relations
  end

  def negative_quantities_relations(stops)
    services_with_negative_quantities = []
    stops.each{ |stop|
      next if stop.is_a?(StopRest) ||
              stop.visit.quantities_operations&.values&.none?{ |q| q == 'empty' } &&
              stop.visit.default_quantities&.values&.none?{ |q| q && q < 0 }

      services_with_negative_quantities.push("s#{stop.id}")
    }
    return [] if services_with_negative_quantities.empty?

    [{
      id: :never_first,
      type: :never_first,
      linked_ids: services_with_negative_quantities
    }]
  end

  def route_orders(routes, options = {})
    routes.map{ |route|
      next if route.vehicle_usage.nil?

      mission_ids = route.stops.map{ |stop|
        next if stop.is_a?(StopRest) && !stop.position? ||
                !stop.active && options[:only_active] ||
                options[:moving_stop_ids]&.include?(stop.id)

        "s#{stop.id}"
      }.compact
      next if mission_ids.empty?

      {
        type: :order,
        linked_ids: mission_ids
      }
    }.compact
  end

  def only_insertion_services(services)
    services.each{ |service|
      timewindows = service.dig(:activity, :timewindows)
      next unless timewindows

      timewindows.delete_at(1)
      timewindows[0].delete(:end)
    }
  end

  def only_insertion_vehicles(routes, vrp)
    keys_to_remove = %i[capacities distance duration maximum_ride_distance maximum_ride_duration rest_ids skills]
    used_vehicle_hash = Hash.new { false }
    vrp[:services].each{ |service|
      service[:sticky_vehicle_ids]&.each{ |sticky_id|
        used_vehicle_hash[sticky_id] = true
      }
    }
    vrp[:vehicles].delete_if{ |vehicle|
      !used_vehicle_hash.key?(vehicle[:id])
    }
    @removed_route_indices = routes.map.with_index{ |route, index|
      next unless route.vehicle_usage?

      next if used_vehicle_hash.key?("v#{route.vehicle_usage.vehicle_id}")

      index
    }.compact

    vrp[:vehicles].each{ |vehicle|
      keys_to_remove.each{ |key| vehicle.delete(key) }

      vehicle[:timewindow]&.delete(:end)
    }
  end

  # Resolutions might contain multiple steps in a hierachical order :
  # - split independent process -> The problem is split in independant sub problems regarding sticky vehicles or skills
  # - solution                  -> Some resolutions might require multiple solutions from a single problem with some perturbations
  # - repetition                -> Multiple Resolutions of a single problem but only return the best solution
  # - split partition process   -> Partitions by vehicle or workday
  # - max split process         -> The max_split_size parameter requires for the problem to be split recursively in two sub problems
  #                                until each sub problem has a size inferior to max_split_size
  # - dichotomous process       -> The dichotomous split follows a similar logic to max_split_size, but also generates subproblems when the recursion
  #                                goes up
  #
  # If the problem is simple, the progression is directly related to the time elapsed as there is only one matrix to compute
  def compute_progression(vrp, result, job_details)
    progression = job_details.dig('avancement')
    return {'first_progression': 0, 'second_progression': 0, 'status': 'queued'} unless progression

    solution_data = compute_solution_data(result.dig('job'), result.dig('solutions')&.last)

    multipart, matrix_bar, resolution_bar =
      if PROGRESSION_KEYS.any?{ |key| progression.include?(key) }
        multiple_steps_progression(progression)
      elsif progression.include?('run optimization')
        single_step_progression(vrp, job_details)
      else
        [nil, 0, 0]
      end
    solution_data.merge!('multipart': multipart, 'first_progression': matrix_bar, 'second_progression': resolution_bar)
    solution_data
  end

  def single_step_progression(vrp, job_details)
    # Resolution graph may not be available. i.e: VROOM did not return intermediate solutions
    @optimization_start ||=  Time.now.to_f - (job_details.dig('graph')&.any? && (job_details.dig('graph').last['time'].to_f / 1000) || 0)
    maximum_duration = vrp[:configuration][:resolution][:duration] / 1000

    current_elapsed = Time.now.to_f - @optimization_start
    [false, 100, 100 * (current_elapsed/maximum_duration).round(2)]
  end

  # Each couple a/b give the progression of the considered step identified by a key
  # By multiplying the current denominator with all the previous ones we are sure that the ratio of the current step
  # will have a smaller impact on the total ratio than the previous steps. This prevents the progress bar to go back
  # and forth. The progression key order defines the hierarchical order of contribution in the total progression.
  def multiple_steps_progression(progression)
    scores = []
    matrix_scores = []
    denominators = []

    PROGRESSION_KEYS.each{ |key|
      a, b = parse_progression(progression, key)
      denominators << b
      scores << 100.0 * a / denominators.reduce(&:*)
      matrix_scores << 100.0 * a / denominators.reduce(&:*) unless key == 'dichotomous process'
    }
    resolution_bar = scores.sum.round(2)
    matrix_bar = matrix_scores.sum.round(2)

    # Remove dicho from denominators as Matrix computation is performed at the end of the steps but before dicho
    denominators.pop
    matrix_bar += progression.include?('run optimization') ? (100.0 / denominators.reduce(&:*)) : 0
    [true, matrix_bar, resolution_bar]
  end

  def parse_progression(progression, key)
    parts = progression.split(' - ')
    section_index = parts.index{ |part| part.include?(key)}
    return [0, 1] unless section_index

    ratio = parts[section_index].split(' ').last
    ratio.split('/').map(&:to_i)
  end

  def compute_solution_data(job, solution)
    solution_data = solution&.slice('cost', 'total_distance', 'total_time', 'elapsed') || {}
    solution_data.merge!(job.slice('status'))
    solution_data.merge('status': 'queued') unless solution_data.key?('status')
    solution_data.merge!('unassigned_size': solution.dig('unassigned')&.size) if solution
    solution_data
  end
end
