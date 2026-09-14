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
class JobTimeout < StandardError; end

class Job < Struct
  def before(job)
    @job = job
    remember_async_job!(job, 'working')
  end

  def job_progress_save(progress)
    # Job is executed inside a transaction (for instance to be sure data are all updated in database when job is deleted)
    # New thread will use a new connection outside this transaction to update job progress
    if @job
      Thread.new do
        @job.progress ||= {}
        @job.progress = JSON.parse(@job.progress) if @job.progress.is_a?(String)
        @job.progress = @job.progress.merge!(progress).to_json
        @job.save
      end.join
    end
  end

  # Delayed::Job: success before destroy; optimizer failure records last_async_jobs then destroys the row.
  # Destroy of a running job is killed. Destroy of an already-failed job keeps failed.
  ASYNC_KINDS = {
    'OptimizerJob' => 'optimizer',
    'GeocoderJob' => 'destination_geocoding',
    'GeocoderDestinationsJob' => 'destination_geocoding',
    'GeocoderStoresJob' => 'store_geocoding'
  }.freeze

  def success(delayed_job)
    remember_async_job!(delayed_job, 'succeeded')
  end

  def failure(delayed_job)
    remember_async_job!(delayed_job, cancelled_outcome?(delayed_job) ? 'killed' : 'failed')
  end

  def cancelled_outcome?(delayed_job)
    (defined?(OptimizerCancelled) && delayed_job.try(:error).is_a?(OptimizerCancelled)) ||
      delayed_job.try(:last_error).to_s.include?('Optimization cancelled')
  end

  def remember_async_job!(delayed_job, status)
    kind = ASYNC_KINDS[self.class.name]
    return unless kind && respond_to?(:customer_id)

    error = delayed_job.try(:last_error).to_s.lines.first&.strip
    error = error.truncate(200) if error.present?

    record = lambda {
      Customer.record_last_async_job!(
        customer_id,
        id: delayed_job.id,
        type: self.class.name.underscore.parameterize(separator: '_').gsub(/_job$/, ''),
        kind: kind,
        status: status,
        error: status == 'failed' ? error : nil,
        planning_id: (planning_id if respond_to?(:planning_id))
      )
    }
    # working must be visible while the worker transaction is still open.
    # queued uses this connection: Thread.new deadlocks if customers is already locked.
    if status == 'working'
      Thread.new { ActiveRecord::Base.connection_pool.with_connection { record.call } }.join
    else
      record.call
      if %w[succeeded failed killed].include?(status) && delayed_job.respond_to?(:async_outcome_remembered=)
        delayed_job.async_outcome_remembered = true
      end
    end
  end

  def self.remember_killed!(delayed_job)
    return if delayed_job.try(:async_outcome_remembered)
    return if delayed_job.try(:failed_at)

    payload = delayed_job.payload_object
    if payload.respond_to?(:customer_id)
      remembered = Customer.uncached { Customer.where(id: payload.customer_id).pick(:last_async_jobs) }
      entry = remembered.is_a?(Hash) ? remembered['optimizer'] : nil
      return if entry.is_a?(Hash) && entry['id'].to_i == delayed_job.id.to_i && entry['status'] == 'succeeded'
    end
    payload.remember_async_job!(delayed_job, 'killed') if payload.respond_to?(:remember_async_job!)
  rescue Delayed::DeserializationError
    nil
  end

  def self.nb_routes(job)
    if job && job.handler
      match = job.handler.match(/nb_route: ([0-9]+)/)
      !match || Integer(match[1])
    end
  end

  def self.on_planning(job, planning_id, ignore_failed: true)
    return if job.blank?
    return if ignore_failed && job.respond_to?(:failed_at) && job.failed_at
    if job.handler
      match = job.handler.match(/planning_id: ([0-9]+)/)
      !match || match[1].to_i == planning_id
    end
  end
end
