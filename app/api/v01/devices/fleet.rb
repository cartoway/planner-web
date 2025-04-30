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
class V01::Devices::Fleet < Grape::API
  namespace :devices do
    namespace :fleet do

      helpers do
        def service
          FleetService.new customer: @customer
        end
      end

      before do
        @customer = current_customer(params[:customer_id])
      end

      rescue_from DeviceServiceError do |e|
        error! V01::Status.code_response(:code_408, before: e.message), 408
      end

      desc 'List Devices.',
        detail: 'List Cartoway Field devices.',
        nickname: 'deviceFleetList',
        is_array: true,
        success: V01::Status.success(:code_200, V01::Entities::DeviceItem),
        failure: V01::Status.failures(is_array: true)
      get '/devices' do
        present service.list_devices, with: V01::Entities::DeviceItem
      end

      desc 'Send Planning Routes.',
        detail: 'In Cartoway Field.',
        nickname: 'deviceFleetSendMultiple',
        success: V01::Status.success(:code_201),
        failure: V01::Status.failures
      params do
        requires :planning_id, type: Integer, desc: 'Planning ID'
      end
      post '/send_multiple' do
        device_send_routes params.slice(:type).merge(device_id: :fleet_user)
      end

      desc 'Clear Route.',
        detail: 'In Cartoway Field.',
        nickname: 'deviceFleetClear',
        success: V01::Status.success(:code_204),
        failure: V01::Status.failures
      params do
        requires :route_id, type: Integer, desc: 'Route ID'
      end
      delete '/clear' do
        device_clear_route
      end

      desc 'Clear multiple routes.',
        detail: 'In Cartoway Field.',
        nickname: 'deviceFleetClearMultiple',
        success: V01::Status.success(:code_204),
        failure: V01::Status.failures
      params do
        requires :external_refs, type: Array do
          requires :fleet_user, type: String
          requires :external_ref, type: String
        end
      end
      delete '/clear_multiple' do
        routes = service.clear_routes_by_external_ref(params[:external_refs])

        routes.each { |route|
          route.clear_sent_to
          route.save!
        }

        present routes, with: V01::Entities::DeviceRouteLastSentAt
      end

      desc 'Get Fleet routes.',
        detail: 'In Cartoway Field.',
        nickname: 'getFleetRoutes',
        is_array: true,
        success: V01::Status.success(:code_200),
        failure: V01::Status.failures(is_array: true)
      params do
        optional :from, type: Date
        optional :to, type: Date
      end
      get '/fetch_routes' do
        routes = service.fetch_routes_by_date(params[:from], params[:to], params[:sync_user])
        hash = {}

        routes.each do |route|
          route[:date] = I18n.l(Time.parse(route[:date]), format: :long)
          planning = Route.find_by(id: route[:route_id]).try(:planning)
          route[:planning_name] = planning.name unless planning.nil?

          if !hash[route[:fleet_user]].nil?
            hash[route[:fleet_user]] << route
          else
            hash[route[:fleet_user]] = [route]
          end
        end

        hash.map { |_, v|
          {
            routes_by_fleet_user: v.group_by{ |route|
              route[:fleet_user]
            }.map{ |key, val|
              { fleet_user: key, routes: val }
            }
          }
        }
      end

      desc 'Synchronise Vehicles.',
        detail: 'In Cartoway Field.',
        nickname: 'deviceFleetSync',
        success: V01::Status.success(:code_204),
        failure: V01::Status.failures
      post '/sync' do
        fleet_sync_vehicles @customer
        status 204
      end

      desc 'Create company with drivers.',
        detail: 'In Cartoway Field.',
        nickname: 'deviceFleetCreateCompanyAndDrivers',
        success: V01::Status.success(:code_200),
        failure: V01::Status.failures
      patch '/create_company' do
        if @customer.reseller.authorized_fleet_administration?
          data = service.create_company['admin_user'].slice('email', 'api_key')
          data['drivers'] = service.create_or_update_drivers(@current_user)
          data
        else
          error! V01::Status.code_response(:code_403), 403
        end
      end

      desc 'Create drivers.',
        detail: 'In Cartoway Field.',
        nickname: 'deviceFleetCreateDrivers',
        success: V01::Status.success(:code_200),
        failure: V01::Status.failures
      patch '/create_or_update_drivers' do
        if @customer.reseller.authorized_fleet_administration?
          service.create_or_update_drivers(@current_user) if @current_customer.reseller.authorized_fleet_administration?
        else
          error! V01::Status.code_response(:code_403), 403
        end
      end
    end
  end
end
