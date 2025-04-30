# Copyright © Mapotempo, 2016
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
class V01::Devices::Tomtom < Grape::API
  namespace :devices do
    namespace :tomtom do

      helpers do
        def service
          TomtomService.new customer: @customer
        end
      end

      before do
        @customer = current_customer(params[:customer_id])
      end

      rescue_from DeviceServiceError do |e|
        error! V01::Status.code_response(:code_408, before: e.message), 408
      end

      desc 'List Devices.',
        detail: 'For TomTom device.',
        nickname: 'deviceTomtomList',
        is_array: true,
        success: V01::Status.success(:code_200, V01::Entities::DeviceItem),
        failure: V01::Status.failures(is_array: true)
      get '/devices' do
        present service.list_devices, with: V01::Entities::DeviceItem
      end

      desc 'Send Planning Routes.',
        detail: 'For TomTom device.',
        nickname: 'deviceTomtomSendMultiple',
        success: V01::Status.success(:code_201),
        failure: V01::Status.failures
      params do
        requires :planning_id, type: Integer, desc: 'Planning ID'
        requires :type, type: String, desc: 'Action Name', values: %w(waypoints orders)
      end
      post '/send_multiple' do
        device_send_routes params.slice(:type).merge(device_id: :tomtom_id)
      end

      desc 'Clear Route.',
        detail: 'For TomTom device.',
        nickname: 'deviceTomtomClear',
        success: V01::Status.success(:code_204),
        failure: V01::Status.failures
      params do
        requires :route_id, type: Integer, desc: 'Route ID'
      end
      delete '/clear' do
        device_clear_route
      end

      desc 'Clear Planning Routes.',
        detail: 'For TomTom device.',
        nickname: 'deviceTomtomClearMultiple',
        success: V01::Status.success(:code_204),
        failure: V01::Status.failures
      params do
        requires :planning_id, type: Integer, desc: 'Planning ID'
      end
      delete '/clear_multiple' do
        device_clear_routes device_id: :tomtom_id
      end

      desc 'Synchronise Vehicles.',
        detail: 'For TomTom device.',
        nickname: 'deviceTomtomSync',
        success: V01::Status.success(:code_204),
        failure: V01::Status.failures
      post '/sync' do
        tomtom_sync_vehicles @customer
        status 204
      end
    end
  end
end
