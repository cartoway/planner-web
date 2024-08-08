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

  expose(:message, documentation: { type: String }, if: lambda { |m, options| m || options[:message] }) { |m, options|
    options.dig(:message) || m
  }
  expose(:id, documentation: { type: Integer })
  expose(:attempts, documentation: { type: Integer })
  expose(:created_at, documentation: { type: Date })
  expose(:failed_at, documentation: { type: Date })
  expose(:locked_at, documentation: { type: Date })
  expose(:progress, documentation: { type: JSON })
  expose(:run_at, documentation: { type: Date })
  # expose(:sanitized_error, documentation: { type: String })
  expose(:type, documentation: { type: String }) { |m|
    m.name.underscore.parameterize(separator: '_').gsub(/_job$/, '')
  }
  # expose(:redirection, documentation: { type: String })
  # expose(:job_type, documentation: { type: String })
  # expose(:delayed_job_id, documentation: { type: Integer })
  # expose(:finished_at, documentation: { type: Date })
end
