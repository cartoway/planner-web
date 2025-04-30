# Copyright © Mapotempo, 2017
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
class V01::Devices::FleetDemo < Grape::API
  namespace :devices do
    namespace :fleet_demo do

      helpers do
        def service
          FleetDemoService.new customer: @customer
        end
      end

      before do
        @customer = current_customer(params[:customer_id])
      end

      rescue_from DeviceServiceError do |e|
        error! V01::Status.code_response(:code_408, before: e.message), 408
      end

      desc 'Send Planning Routes.',
        detail: 'In Cartoway Field demo version (Cartoway Field demo).',
        nickname: 'deviceFleetDemoSendMultiple',
        success: V01::Status.success(:code_201),
        failure: V01::Status.failures
      params do
        requires :planning_id, type: Integer, desc: 'Planning ID'
      end
      post '/send_multiple' do
        device_send_routes params.slice(:type).merge(device_id: :planner_fleet_id)
      end

      desc 'Clear Route.',
        detail: 'In Cartoway Field demo version (Cartoway Field demo).',
        nickname: 'deviceFleetDemoClear',
        success: V01::Status.success(:code_204),
        failure: V01::Status.failures
      params do
        requires :route_id, type: Integer, desc: 'Route ID'
      end
      delete '/clear' do
        device_clear_route
      end

      desc 'Clear Planning Routes.',
        detail: 'In Cartoway Field demo version (Cartoway Field demo).',
        nickname: 'deviceFleetDemoClearMultiple',
        success: V01::Status.success(:code_204),
        failure: V01::Status.failures
      params do
        requires :planning_id, type: Integer, desc: 'Planning ID'
      end
      delete '/clear_multiple' do
        device_clear_routes device_id: :planner_fleet_id
      end
    end
  end
end
