# Copyright © Cartoway, 2025
#
# This file is part of Cartoway Planner.
#
# Cartoway Planner is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Cartoway Planner is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Cartoway Planner. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#

class DelayedJobManager
  using AfterCommitHelper

  class << self
    def enqueue_with_delay(job_class, *args, delay_seconds: 30)
      return unless Planner::Application.config.delayed_job_use

      Delayed::Job.transaction do
        job = job_class.new(*args)

        job_signature = build_job_signature(job_class, *args)

        existing_job = Delayed::Job.where(
          "handler LIKE ? AND handler LIKE ?",
          "%#{job_class.name}%",
          "%#{job_signature}%"
        ).first

        if existing_job && existing_job.locked_at.nil?
          # Only update if the job is not currently running or locked
          begin
            existing_job.update_column(:run_at, delay_seconds.seconds.from_now)
          rescue PG::TRSerializationFailure, PG::TRDeadlockDetected, ActiveRecord::StatementInvalid
            # Job is being modified by another process, skip update
            Rails.logger.debug "Skipping job update due to concurrency: #{job_class.name}"
          end
          existing_job
        else
          Delayed::Job.enqueue(job, run_at: delay_seconds.seconds.from_now)
        end
      end
    end

    def enqueue_with_delay_safe(job_class, *args, delay_seconds: 30)
      return unless Planner::Application.config.delayed_job_use

      # Use after_commit to ensure job is only enqueued after transaction commit
      after_commit do
        enqueue_with_delay(job_class, *args, delay_seconds: delay_seconds)
      end
    end

    def enqueue_simplify_geojson_tracks_job(customer_id, route_id, delay_seconds: 30)
      SimplifyGeojsonTracksJob.new(customer_id, route_id).perform
      # enqueue_with_delay(SimplifyGeojsonTracksJob, customer_id, route_id, delay_seconds: delay_seconds)
    end

    private

    def build_job_signature(job_class, *args)
      if job_class == SimplifyGeojsonTracksJob
        customer_id, route_id = args
        "customer_id: #{customer_id}\nroute_id: #{route_id}"
      else
        args.join(' ')
      end
    end
  end
end
