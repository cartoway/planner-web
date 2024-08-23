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
OptimizerJobStruct ||= Job.new(:customer_id, :planning_id, :route_id, :options)
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
    optimum = nil
    return true if @job&.progress && JSON.parse(@job.progress)&.dig('failed') && @job.attempts > 0

    Delayed::Worker.logger.info "OptimizerJob customer_id=#{customer_id} planning_id=#{planning_id} perform"
    job_progress_save({ 'status': 'queued', 'first_progression': 0, 'second_progression': 0, 'completed': false })
    planning = Planning.where(id: planning_id).first!

    routes = route_filter(planning)

    if routes.select(&:vehicle_usage_id).any?
      begin
        planning.optimize(routes, **options) do |planning, routes, options|
          options = job_options(planning).merge(options)
          optimum = Mapotempo::Application.config.optimizer.optimize(planning, routes, **options) { |job_id, solution_data|
            if @job
              job_progress_save solution_data.merge('job_id': job_id, 'completed': false)
              Delayed::Worker.logger.info "OptimizerJob customer_id=#{customer_id} planning_id=#{planning_id} #{@job.progress}"
            end
          }
          if @job
            job_progress_save(@job.progress.merge({ 'first_progression': 100, 'second_progression': 100, 'completed': true }))
            Delayed::Worker.logger.info "OptimizerJob customer_id=#{customer_id} planning_id=#{planning_id} #{@job.progress}"
          end
        end
      rescue VRPNoSolutionError, VRPUnprocessableError => e
        if @job
          job_progress_save(@job.progress.merge({ 'failed': 'true' }))
          Delayed::Worker.logger.info "OptimizerJob customer_id=#{customer_id} planning_id=#{planning_id} #{@job.progress}"
        end
        raise e
      end
    end

    # Apply result
    if optimum
      planning.set_stops(routes, optimum, **{ global: options[:global], active_only: options[:active_only], insertion_only: options[:insertion_only], moving_stop_ids: options[:moving_stop_ids] })
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

  def route_filter(planning)
    routes = []
    if options[:insertion_only] && options[:moving_stop_ids] && !route_id && !options[:global]
      route_ids = Stop.where(id: options[:moving_stop_ids]).pluck(:route_id).uniq
      routes = planning.routes.where(id: route_ids) if route_ids.exclude?(nil)
    end
    routes = planning.routes if routes.empty?
    routes = routes.select { |r|
      (route_id && r.id == route_id) || (!route_id && !options[:global] && r.vehicle_usage_id && r.size_active > 0 && !r.locked) || (!route_id && options[:global] && !r.locked)
    }
    routes.unshift(planning.routes.first) if !options[:global] && !planning.routes.first[:locked] && !route_id
    routes
  end

  def job_options(planning)
    optimize_time = planning.customer.optimization_time || @@optimize_time
    {
      synchronous: false,
      name: "c#{planning.customer_id} " + planning.name,
      optimize_time: @@optimize_time_force || (optimize_time ? optimize_time * 1000 : nil),
      max_split_size: planning.customer.optimization_max_split_size || @@max_split_size,
      stop_soft_upper_bound: planning.customer.optimization_stop_soft_upper_bound || @@stop_soft_upper_bound,
      vehicle_soft_upper_bound: planning.customer.optimization_vehicle_soft_upper_bound || @@vehicle_soft_upper_bound,
      cluster_threshold: planning.customer.optimization_cluster_size || @@cluster_size,
      cost_waiting_time: planning.customer.optimization_cost_waiting_time || @@cost_waiting_time,
      force_start: planning.customer.optimization_force_start.nil? ? @@force_start : planning.customer.optimization_force_start,
      optimize_minimal_time: planning.customer.optimization_minimal_time || @@optimize_minimal_time
    }
  end
end
