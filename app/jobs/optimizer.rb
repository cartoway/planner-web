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
require 'optimizer_job'

class Optimizer
  @@optimize_time = Planner::Application.config.optimize_time
  @@optimize_time_force = Planner::Application.config.optimize_time_force
  @@max_split_size = Planner::Application.config.optimize_max_split_size
  @@stop_soft_upper_bound = Planner::Application.config.optimize_stop_soft_upper_bound
  @@vehicle_soft_upper_bound = Planner::Application.config.optimize_vehicle_soft_upper_bound
  @@cluster_size = Planner::Application.config.optimize_cluster_size
  @@cost_waiting_time = Planner::Application.config.optimize_cost_waiting_time
  @@force_start = Planner::Application.config.optimize_force_start
  @@optimize_minimal_time = Planner::Application.config.optimize_minimal_time

  def self.kill_optimize(optim_job_id)
    Planner::Application.config.optimizer.kill_solve(optim_job_id)
  end

  def self.optimize(planning, route, options = { global: false, synchronous: false, active_only: true, ignore_overload_multipliers: [], nb_route: 0 })
    if route && route.size_active <= 1 && options[:active_only]
      # Nothing to optimize
      route.compute
      planning.save
    else
      if planning.customer.job_optimizer
        # Customer already run an optimization
        planning.errors.add(:base, I18n.t('errors.planning.already_optimizing'))
        false
      else
        job = OptimizerJob.new(planning.customer.id, planning.id, route&.id, **options)
        if !options[:synchronous] && Planner::Application.config.delayed_job_use
          planning.customer.job_optimizer = Delayed::Job.enqueue(job)
          planning.customer.job_optimizer.save!
        else
          job.perform
        end
      end
    end
  end
end
