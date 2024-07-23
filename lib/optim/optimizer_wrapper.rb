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

  # positions with stores at the end
  # services Array[Hash{start1: , end1: , duration: , stop_id: , vehicle_id: , quantities: [], quantities_operations: [], rest: boolean}]
  # vehicles Array[Hash{id: , open: , close: , stores: [], rests: [], capacities: []}]
  def optimize(positions, services, vehicles, options, &progress)
    key = Digest::MD5.hexdigest(Marshal.dump([positions, services, vehicles, options]))

    result = @cache.read(key)
    if result
      result = JSON.parse(result)
    else
      vrp = build_vrp(positions, services, vehicles, options)
      result = solve(vrp, progress, key)
    end

    [result['solutions'][0]['unassigned'] ? result['solutions'][0]['unassigned'].select{ |activity| activity['service_id'] }.collect{ |activity|
      activity['service_id'][1..-1].to_i
    } : []] + vehicles.collect{ |vehicle|
      route = result['solutions'][0]['routes'].find{ |r| r['vehicle_id'] == "v#{vehicle[:id]}" }
      !route ? [] : route['activities'].collect{ |activity|
        if activity.key?('service_id')
          activity['service_id'][1..-1].to_i
        elsif activity.key?('rest_id')
          activity['rest_id'][1..-1].to_i
        end
      }.compact # stores are not returned anymore
    }
  end

  def build_vrp(positions, services, vehicles, options)
    rests = vehicles.flat_map{ |v| v[:rests] }
      services_with_negative_quantities = []

      all_skills = vehicles.map { |v| v[:skills] }.flatten.compact
      use_skills = !all_skills.empty?

      services_late_multiplier = (options[:stop_soft_upper_bound] && options[:stop_soft_upper_bound] > 0) ? options[:stop_soft_upper_bound] : nil
      vehicles_cost_late_multiplier = (options[:vehicle_soft_upper_bound] && options[:vehicle_soft_upper_bound] > 0) ? options[:vehicle_soft_upper_bound] : nil
      # FIXME: ortools is not able to support non null vehicle late multiplier for global optim
      if vehicles.size > 1 && !services.all?{ |s| s[:vehicle_usage_id] }
        vehicles_cost_late_multiplier = nil unless options[:vehicle_soft_upper_bound] != Mapotempo::Application.config.optimize_vehicle_soft_upper_bound
      end

      vrp = {
        units: vehicles.flat_map{ |v| v[:capacities] && v[:capacities].map{ |c| c[:deliverable_unit_id] } }.uniq.map{ |k|
          {id: "u#{k}"}
        },
        points: positions.each_with_index.collect{ |pos, i|
          {
            id: "p#{i}",
            location: {
              lat: pos[0],
              lon: pos[1]
            }
          }
        },
        rests: rests.collect{ |rest|
          {
            id: "r#{rest[:stop_id]}",
            timewindows: [{
              start: rest[:start1],
              end: rest[:end1]
            }],
            duration: rest[:duration]
          }
        },
        vehicles: build_vehicles(vehicles, services, options.merge(use_skills: use_skills)),
        services: services.each_with_index.collect{ |service, index|
          services_with_negative_quantities.push("s#{service[:stop_id]}") if service[:quantities_operations] && service[:quantities_operations].values.any?{ |q| q == 'empty' } || service[:quantities] && service[:quantities].values.any?{ |q| q && q < 0 }
          {
            id: "s#{service[:stop_id]}",
            type: 'service',
            sticky_vehicle_ids: service[:vehicle_usage_id] ? ["v#{service[:vehicle_usage_id]}"] : nil, # to force an activity on a vehicle (for instance geoloc rests)
            activity: {
              point_id: "p#{index}",
              timewindows: [
                (service[:start1] || service[:end1]) && {
                  start: service[:start1],
                  end: service[:end1]
                },
                (service[:start2] || service[:end2]) && {
                  start: service[:start2],
                  end: service[:end2]
                },
              ].compact,
              duration: service[:duration],
              late_multiplier: service[:rest] ? nil : services_late_multiplier
            },
            priority: service[:priority] && (service[:priority].to_i - 4).abs,
            quantities: service[:quantities] ? service[:quantities].each.map{ |k, v|
              v ? {
                unit_id: "u#{k}",
                value: v,
                fill: service[:quantities_operations][k] == 'fill' || nil,
                empty: service[:quantities_operations][k] == 'empty' || nil
              }.compact : nil
            }.compact : [],
            skills: (use_skills && service[:skills]) ? (all_skills & service[:skills]) : nil
          }.delete_if{ |_, v| !v }
        },
        relations: [],
        configuration: {
          preprocessing: {
            max_split_size: options[:max_split_size],
            cluster_threshold: options[:cluster_threshold],
            prefer_short_segment: true,
            first_solution_strategy: :self_selection,
          },
          resolution: {
            duration: options[:optimize_time] ? options[:optimize_time] * vehicles.size : nil,
            # iterations_without_improvment: 100,
            initial_time_out: options[:optimize_minimal_time] ? options[:optimize_minimal_time] * vehicles.size * 1000 : nil,
            time_out_multiplier: 2
          },
          restitution: {
            intermediate_solutions: false
          }
        },
        name: options[:name]
      }
      vrp[:relations] += collect_relations(services, services_with_negative_quantities, options)
      vrp
  end

  def collect_relations(services, services_with_negative_quantities, options)
    relations = []
    relations += filter_option_relations(services, options)
    relations += position_relations(services)
    relations += negative_quantities_relations(services_with_negative_quantities)
    relations
  end

  def filter_option_relations(services, options)
    return [] unless options[:relations]

    service_hash = services.map{ |s| [s[:stop_id], s] }.to_h

    options[:relations].delete_if{ |relation|
      relation[:linked_ids].any?{ |id| !service_hash.key?(id) }
    }
    options[:relations].each{ |relation|
      relation[:linked_ids].map!{ |id| "s#{id}"}
    }
    options[:relations]
  end

  def position_relations(services)
    relations = []
    services.group_by{ |serv| serv[:force_position] }.each{ |position, servs|
      next if position.nil? || position == 'neutral'

      relations << {
        type: POSITION_KEYS[position.to_sym],
        linked_ids: servs.map{ |serv| "s#{serv[:stop_id]}" }}
    }
    relations
  end

  def negative_quantities_relations(services_with_negative_quantities)
    return [] if services_with_negative_quantities.empty?

    [{
      id: :never_first,
      type: :never_first,
      linked_ids: services_with_negative_quantities
    }]
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
    @optimization_start ||=  Time.now.to_f - (job_details.dig('graph')&.any? && job_details.dig('graph').last['time'].to_f / 1000 || 0)
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

  def build_vehicles(vehicles, services, options = {})
    shift_stores = 0
    vehicles_cost_late_multiplier = (options[:vehicle_soft_upper_bound] && options[:vehicle_soft_upper_bound] > 0) ? options[:vehicle_soft_upper_bound] : nil

    vehicles.collect{ |vehicle|
      store_start = if vehicle[:stores].include?(:start)
        value = "p#{shift_stores + services.size}"
        shift_stores += 1
        value
      end
      store_end = if vehicle[:stores].include?(:stop)
        value = "p#{shift_stores + services.size}"
        shift_stores += 1
        value
      end
      v = {
        id: "v#{vehicle[:id]}",
        router_mode: vehicle[:router].try(&:mode),
        router_dimension: vehicle[:router_dimension],
        # router_options are flattened and merged below
        speed_multiplier: vehicle[:speed_multiplier],
        area: vehicle[:speed_multiplier_areas] ? vehicle[:speed_multiplier_areas].map{ |a| a[:area].join(',') }.join('|') : nil,
        speed_multiplier_area: vehicle[:speed_multiplier_areas] ? vehicle[:speed_multiplier_areas].map{ |a| a[:speed_multiplier_area] }.join('|') : nil,
        timewindow: {start: vehicle[:open], end: vehicle[:close]},
        duration: vehicle[:work_time],
        distance: vehicle[:max_distance],
        maximum_ride_distance: vehicle[:max_ride_distance],
        maximum_ride_time: vehicle[:max_ride_duration],
        start_point_id: store_start,
        end_point_id: store_end,
        cost_fixed: 0,
        cost_distance_multiplier: vehicle[:router_dimension] == 'distance' ? 1 : 0,
        cost_time_multiplier: vehicle[:router_dimension] == 'time' ? 1 : 0,
        cost_waiting_time_multiplier: vehicle[:router_dimension] == 'time' ? options[:optimization_cost_waiting_time] : 0,
        cost_late_multiplier: vehicles_cost_late_multiplier,
        shift_preference: !vehicle[:force_start].nil? ? vehicle[:force_start]: options[:force_start] ? 'force_start' : nil,
        rest_ids: vehicle[:rests].collect{ |rest|
          "r#{rest[:stop_id]}"
        },
        capacities: vehicle[:capacities] ? vehicle[:capacities].map{ |c|
          c[:capacity] && c[:overload_multiplier] >= 0 ? {
            unit_id: "u#{c[:deliverable_unit_id]}",
            limit: c[:capacity],
            overload_multiplier: c[:overload_multiplier]
          } : nil
        }.compact : [],
        skills: options[:use_skills] ? [vehicle[:skills]] : nil
      }.merge(vehicle[:router_options] || {})
      v
    }
  end
end
