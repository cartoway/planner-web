# Copyright © Frédéric Rodrigo, 2023
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
class V01::Entities::Job < Grape::Entity
  def self.entity_name
    'V01_Job'
  end

  expose(:message, documentation: { type: String, desc: 'Optional status message (for example when the job is in transmission).' }, if: lambda { |m, options| m || options[:message] }) { |m, options|
    options.dig(:message) || m
  }
  expose(:id, documentation: { type: Integer, desc: 'Delayed job id. Poll GET /jobs/:id until the job disappears (success) or failed_at is set.', example: 88 })
  expose(:attempts, documentation: { type: Integer, desc: 'Number of execution attempts.', example: 1 })
  expose(:created_at, documentation: { type: Date, desc: 'When the job was enqueued.' })
  expose(:failed_at, documentation: { type: Date, desc: 'Set when the job failed. Null while running or after success (job is then deleted).' })
  expose(:locked_at, documentation: { type: Date, desc: 'Set while a worker is executing the job.' })
  expose(:progress, documentation: { type: JSON, desc: 'Optimizer/geocoder progress payload (percent, phase, nested job_id). Shape depends on job type.' })
  expose(:run_at, documentation: { type: Date, desc: 'Scheduled run time.' })
  # expose(:sanitized_error, documentation: { type: String })
  expose(:type, documentation: { type: String, desc: 'Job kind derived from the class name: optimizer, destination_geocoding, store_geocoding.', example: 'optimizer' }) { |m|
    m.name.underscore.parameterize(separator: '_').gsub(/_job$/, '')
  }
  # expose(:redirection, documentation: { type: String })
  # expose(:job_type, documentation: { type: String })
  # expose(:delayed_job_id, documentation: { type: Integer })
  # expose(:finished_at, documentation: { type: Date })
end
