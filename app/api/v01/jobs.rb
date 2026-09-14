# Copyright © Mapotempo, 2014-2016
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
require 'coerce'

class V01::Jobs < Grape::API
  helpers SharedParams
  helpers do
    # Never trust parameters from the scary internet, only allow the white list through.
    def job_params
      p = ActionController::Parameters.new(params)
      p = p[:job] if p.key?(:job)
      p.permit(:label, :ref, :color, :icon, :icon_size)
    end

  end

  ID_DESC = 'Id field value".'.freeze

  resource :jobs do
    desc 'Fetch customer\'s jobs.',
         detail: 'Live optimizer/geocoding jobs plus the last succeeded job of each kind (recorded when Delayed::Job is destroyed on success).',
         nickname: 'getJobs',
         is_array: true,
         success: V01::Entities::Job
    get do
      live = current_customer.live_async_jobs
      remembered = current_customer.remembered_async_jobs.reject { |job| live.any? { |live_job| live_job.id == job.id } }
      present live + remembered, with: V01::Entities::Job
    end

    desc 'Return a job.',
      detail: 'HTTP 200 with status running or failed while the job exists, succeeded after successful completion. HTTP 404 if this id was never a job of this customer.',
      nickname: 'getJob',
      success: V01::Entities::Job
    params do
      requires :id, type: Integer, desc: ID_DESC
    end
    get ':id' do
      job = current_customer.find_async_job(params[:id])
      if job
        present job, with: V01::Entities::Job
      else
        error! 'Job not found', 404
      end
    end

    desc 'Cancel job.',
      detail: 'Cancels a running optimizer or geocoding job. HTTP 409 if the optimizer job is already in transmission to the solver. Returns 204 on success.',
      nickname: 'deleteJob'
    params do
      requires :id, type: Integer, desc: ID_DESC
    end
    delete ':id' do
      customer = current_customer
      if customer.job_optimizer && customer.job_optimizer_id == params[:id]
        # Secure condition to avoid deleting job while in transmission
        raise Exceptions::JobInTransmissionError if !customer.job_optimizer.locked_at.nil? && customer.job_optimizer.failed_at.nil? && !customer.job_optimizer.progress&.dig('job_id')

        Optimizer.kill_optimize(customer.job_optimizer.progress&.dig('job_id'))
        customer.job_optimizer.destroy
      elsif customer.job_destination_geocoding && customer.job_destination_geocoding_id == params[:id]
        customer.job_destination_geocoding.destroy
      elsif customer.job_store_geocoding && customer.job_store_geocoding_id == params[:id]
        customer.job_store_geocoding.destroy
      end
      status 204
    rescue Exceptions::JobInTransmissionError
      status 409
      present customer.job_optimizer, with: V01::Entities::Job, message: I18n.t('errors.planning.transmission_in_progress')
    end
  end
end
