# Copyright © Mapotempo, 2013-2015
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
require 'optim/ort'

OptimizerJobStruct ||= Job.new(:customer_id, :planning_id, :route_id, :global, :active_only, :ignore_overload_multipliers, :nb_route)
class OptimizerJob < OptimizerJobStruct
  @@optimize_time = Mapotempo::Application.config.optimize_time
  @@optimize_time_force = Mapotempo::Application.config.optimize_time_force
  @@max_split_size = Mapotempo::Application.config.optimize_max_split_size
  @@stop_soft_upper_bound = Mapotempo::Application.config.optimize_stop_soft_upper_bound
  @@vehicle_soft_upper_bound = Mapotempo::Application.config.optimize_vehicle_soft_upper_bound
  @@cluster_size = Mapotempo::Application.config.optimize_cluster_size
  @@cost_waiting_time = Mapotempo::Application.config.optimize_cost_waiting_time
  @@force_start = Mapotempo::Application.config.optimize_force_start
  @@optimize_minimal_time = Mapotempo::Application.config.optimize_minimal_time

  def perform
    return true if @job && @job.progress&.dig('failed') && @job.attempts > 0

    Delayed::Worker.logger.info "OptimizerJob customer_id=#{customer_id} planning_id=#{planning_id} perform"
    job_progress_save({ 'status': 'queued', 'first_progression': 0, 'second_progression': 0, 'completed': false })
    planning = Planning.where(id: planning_id).first!
    routes = planning.routes.select { |r|
      (route_id && r.id == route_id) || (!route_id && !global && r.vehicle_usage_id && r.size_active > 0) || (!route_id && global)
    }.reject(&:locked)

    routes.unshift(planning.routes.first) if !global && !planning.routes.first[:locked] && !route_id

    optimize_time = planning.customer.optimization_time || @@optimize_time

    optimum = unless routes.select(&:vehicle_usage_id).empty?
      begin
        planning.optimize(routes, global: global, synchronous: false, active_only: active_only, ignore_overload_multipliers: ignore_overload_multipliers) do |positions, services, vehicles|
          optimum = Mapotempo::Application.config.optimizer.optimize(
            positions, services, vehicles,
            name: "c#{planning.customer_id} " + planning.name,
            optimize_time: @@optimize_time_force || (optimize_time ? optimize_time * 1000 : nil),
            max_split_size: planning.customer.optimization_max_split_size || @@max_split_size,
            stop_soft_upper_bound: planning.customer.optimization_stop_soft_upper_bound || @@stop_soft_upper_bound,
            vehicle_soft_upper_bound: planning.customer.optimization_vehicle_soft_upper_bound || @@vehicle_soft_upper_bound,
            cluster_threshold: planning.customer.optimization_cluster_size || @@cluster_size,
            cost_waiting_time: planning.customer.optimization_cost_waiting_time || @@cost_waiting_time,
            force_start: planning.customer.optimization_force_start.nil? ? @@force_start : planning.customer.optimization_force_start,
            optimize_minimal_time: planning.customer.optimization_minimal_time || @@optimize_minimal_time,
            relations: planning.stops_relationss
          ) { |job_id, solution_data|
            if @job
              job_progress_save solution_data.merge('job_id': job_id, 'completed': false)
              Delayed::Worker.logger.info "OptimizerJob customer_id=#{customer_id} planning_id=#{planning_id} #{@job.progress}"
            end
          }
          if @job
            job_progress_save(JSON.parse(@job.progress).merge({ 'first_progression': 100, 'second_progression': 100, 'completed': true }))
            Delayed::Worker.logger.info "OptimizerJob customer_id=#{customer_id} planning_id=#{planning_id} #{@job.progress}"
          end
          optimum
        end
      rescue VRPNoSolutionError, VRPUnprocessableError => e
        if @job
          job_progress_save(JSON.parse(@job.progress).merge({ 'failed': 'true' }))
          Delayed::Worker.logger.info "OptimizerJob customer_id=#{customer_id} planning_id=#{planning_id} #{@job.progress}"
        end
        raise e
      end
    end

    # Apply result
    if optimum
      planning.set_stops(routes, optimum, { global: global, active_only: active_only })
      planning.compute_saved
      planning.save!
    end
  rescue => e
    if @job
      puts e.message
      puts e.backtrace.join("\n")
    end
    raise e
  end

  def max_attempts
    1
  end
end
