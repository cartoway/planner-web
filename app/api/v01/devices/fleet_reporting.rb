# Copyright © Mapotempo, 2019
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

# Specific file to get reporting because it needs to return specific content types (csv)
class V01::Devices::FleetReporting < Grape::API
  content_type :json, 'application/json'
  content_type :csv, 'text/csv'
  default_format :json

  namespace :devices do
    namespace :fleet do
      namespace :reporting do
        helpers do
          def service
            FleetService.new customer: @customer
          end
        end

        before do
          @customer = current_customer(params[:customer_id])
        end

        desc 'Get reporting.',
          detail: "Get reporting from Cartoway Field missions. Range between begin_date and end_date must be inferior to #{SharedParams::MAX_DAYS} days.",
          nickname: 'reporting.',
          http_codes: [
            V01::Status.success(:code_200),
            V01::Status.success(:code_204)
          ].concat(V01::Status.failures)
        params do
          requires :begin_date, type: Date, coerce_with: ->(d) { Date.strptime(d.to_s, I18n.t('time.formats.datepicker')).strftime(ACTIVE_RECORD_DATE_MASK).to_date }, desc: 'Select only plannings after this date.' + SharedParams::DATE_DESC
          requires :end_date, type: Date, coerce_with: ->(d) { Date.strptime(d.to_s, I18n.t('time.formats.datepicker')).strftime(ACTIVE_RECORD_DATE_MASK).to_date }, desc: 'Select only plannings before this date.' + SharedParams::DATE_DESC
          optional :with_actions, type: Boolean, desc: 'Get history of actions'
        end
        get do
          if params[:end_date] < params[:begin_date]
            error!(I18n.t('reporting.download.end_date_inferior'), 400)
          elsif (params[:end_date] - params[:begin_date]).to_i > SharedParams::MAX_DAYS
            error!(I18n.t('reporting.download.max_interval_reached'), 400)
          else
            service.reporting(params) || status(204)
          end
        end
      end
    end
  end
end
