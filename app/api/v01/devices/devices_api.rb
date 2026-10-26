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
class V01::Devices::DevicesApi < Grape::API
  helpers V01::Devices::DeviceHelpers

  namespace :devices do
    params do
      requires :device, type: Symbol
    end
    segment '/:device' do

      before do
        current_customer(params[:id]) if @current_user.admin?
      end

      rescue_from DeviceServiceError do |e|
        error! V01::Status.code_response(:code_408, before: e.message), 408
      end

      desc 'Validate device Credentials.',
        detail: 'Generic device.',
        nickname: 'checkAuth',
        success: V01::Status.success(:code_204),
        failure: V01::Status.failures
      params do
        requires :id, type: Integer, desc: 'Customer ID as we need to get customer devices'
      end
      get 'auth/:id' do
        device = @current_customer.device.enableds[params[:device].to_sym]
        if device && device.respond_to?('check_auth')
          require_params = device.respond_to?('definition') && device.definition[:forms][:settings] && device.definition[:forms][:settings].keys
          if require_params && require_params.all?{ |k| params.keys.include? k }
            device.check_auth(params) # raises DeviceServiceError
            status 204
          else
            error! V01::Status.code_response(:code_400), 400
          end
        else
          error! V01::Status.code_response(:code_404, 'Device'), 404
        end
      end

      desc 'Send OperationRoute.',
        detail: 'Generic device send for an OperationRoute (GPS devices). Deliver: use POST /devices/deliver/send or POST /operations/:id/transmit (email/SMS).',
        nickname: 'sendRoute',
        success: V01::Status.success(:code_201, V01::Entities::DeviceRouteLastSentAt),
        failure: V01::Status.failures(add: [:code_410, :code_422])
      params do
        requires :operation_route_id, type: Integer, desc: 'OperationRoute ID'
        optional :type, type: Symbol, desc: 'Action Name'
      end
      post 'send' do
        if params[:device].to_sym == :deliver
          error! V01::Status.code_response(:code_410, message: V01::Devices::Deliver::PLANNING_GONE), 410
        end
        device = @current_customer.device.enableds[params[:device].to_sym]
        if device && device.respond_to?('send_route')
          operation_route = find_operation_route!
          planning_route = planning_route_for!(operation_route)
          Route.transaction do
            device.send_route(@current_customer, planning_route, params.slice(:type))
            planning_route.set_send_to(device.definition[:label_small])
            planning_route.save!
            operation_route.mark_sent!(device.definition[:label_small])
            present operation_route, with: V01::Entities::DeviceRouteLastSentAt
          end
        else
          error! V01::Status.code_response(:code_404, 'Device'), 404
        end
      end
    end
  end
end
