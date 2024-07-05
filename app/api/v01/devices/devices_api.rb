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
  namespace :devices do
    params do
      requires :device, type: Symbol
    end
    segment '/:device' do

      before do
        current_customer(params[:id]) if @current_user.admin?
      end

      rescue_from DeviceServiceError do |e|
        error! e.message, 200
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
        device = @current_customer.device.enableds[params[:device]]
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

      desc 'Send Route.',
        detail: 'Generic device.',
        nickname: 'sendRoute',
        success: V01::Status.success(:code_201),
        failure: V01::Status.failures
      params do
        requires :route_id, type: Integer, desc: 'Route ID'
        optional :type, type: Symbol, desc: 'Action Name'
      end
      post 'send' do
        device = @current_customer.device.enableds[params[:device]]
        if device && device.respond_to?('send_route')
          Route.transaction do
            route = Route.for_customer_id(@current_customer.id).find params[:route_id]
            device.send_route(@current_customer, route, params.slice(:type))
            route.set_send_to(device.definition[:label_small]) # TODO: set_send_to already performed in device_services.rb
            route.save!
            present route, with: V01::Entities::DeviceRouteLastSentAt
          end
        else
          error! V01::Status.code_response(:code_404, 'Device'), 404
        end
      end
    end
  end
end
