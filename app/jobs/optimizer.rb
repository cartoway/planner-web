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
require 'optimizer_job'

class Optimizer
  @@optimize_time = Mapotempo::Application.config.optimize_time
  @@optimize_time_force = Mapotempo::Application.config.optimize_time_force
  @@max_split_size = Mapotempo::Application.config.optimize_max_split_size
  @@stop_soft_upper_bound = Mapotempo::Application.config.optimize_stop_soft_upper_bound
  @@vehicle_soft_upper_bound = Mapotempo::Application.config.optimize_vehicle_soft_upper_bound
  @@cluster_size = Mapotempo::Application.config.optimize_cluster_size
  @@cost_waiting_time = Mapotempo::Application.config.optimize_cost_waiting_time
  @@force_start = Mapotempo::Application.config.optimize_force_start
  @@optimize_minimal_time = Mapotempo::Application.config.optimize_minimal_time

  def self.kill_optimize(optim_job_id)
    Mapotempo::Application.config.optimizer.kill_solve(optim_job_id)
  end

  def self.optimize(planning, route, options = { global: false, synchronous: false, active_only: true, ignore_overload_multipliers: [], nb_route: 0 })
    optimize_time = planning.customer.optimization_time || @@optimize_time
    if route && route.size_active <= 1 && options[:active_only]
      # Nothing to optimize
      route.compute
      planning.save
    elsif !options[:synchronous] && Mapotempo::Application.config.delayed_job_use
      if planning.customer.job_optimizer
        # Customer already run an optimization
        planning.errors.add(:base, I18n.t('errors.planning.already_optimizing'))
        false
      else
        optimizer_job = nil
        retry_counter = 0
        # Delayed Job might have loaded deprecated version from older jobs
        begin
          optimizer_job = OptimizerJob.new(planning.id, route && route.id, options[:global], options[:active_only], options[:ignore_overload_multipliers], options[:nb_route])
        rescue TypeError => e
          ActionDispatch::Reloader.cleanup!
          ActionDispatch::Reloader.prepare!
          Raven.capture_exception(e)
          Rails.logger.error e.message
          Rails.logger.error e.backtrace.join("\n")
          retry if (retry_counter += 1) < 3
        end
        planning.customer.job_optimizer = Delayed::Job.enqueue(optimizer_job)
        planning.customer.job_optimizer.save!
      end
    else
      routes = planning.routes.select { |r|
        (route && r.id == route.id) || (!route && !options[:global] && r.vehicle_usage_id && r.size_active > 1) || (!route && options[:global])
      }.reject(&:locked)

      routes.unshift(planning.routes.first) if !options[:global] && !planning.routes.first[:locked] && !route

      optimum = unless routes.select(&:vehicle_usage_id).empty?
        planning.optimize(routes, options) do |positions, services, vehicles|
          Mapotempo::Application.config.optimizer.optimize(
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
            relations: planning.stop_relations
          )
        end
      end

      if optimum
        planning.set_stops(routes, optimum, { global: options[:global], active_only: options[:active_only] })
        routes.each{ |r|
          r.reload # Refresh stops order
          r.compute
          r.save!
        }
        planning.reload
        planning.save!
      else
        false
      end
    end
  end
end
