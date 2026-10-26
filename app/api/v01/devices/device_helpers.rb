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
module V01::Devices
  module DeviceHelpers
    def devices_customer
      @customer || @current_customer
    end

    def find_operation!
      devices_customer.operations.find(params[:operation_id])
    end

    def find_operation_route!
      OperationRoute.joins(:operation).merge(devices_customer.operations).find(params[:operation_route_id])
    end

    # Bridge: GPS device libs still consume planning Route; API surface is OperationRoute.
    def planning_route_for!(operation_route)
      route = operation_route.route
      error!({ message: 'OperationRoute has no linked planning route to send.', status: 422 }, 422) unless route

      route
    end

    def device_send_label
      service.service.definition[:label_small]
    end

    def device_send_routes(options = {})
      operation = find_operation!
      operation_routes = operation.operation_routes.planned.where.not(vehicle_id: nil).includes(:vehicle, :route)
      if options[:device_id]
        operation_routes = operation_routes.select { |oroute| oroute.vehicle&.devices&.[](options[:device_id]).present? }
      end
      operation_routes = operation_routes.select { |oroute|
        route = oroute.route
        route && route.stops.only_active_stop_visits.any?(&:position?)
      }
      operation_routes.each do |operation_route|
        Route.transaction do
          planning_route = planning_route_for!(operation_route)
          service.send_route(planning_route, options)
          planning_route.save!
          operation_route.mark_sent!(device_send_label)
        end
      end
      present operation_routes, with: V01::Entities::DeviceRouteLastSentAt
    end

    def device_clear_route(_options = {})
      operation_route = find_operation_route!
      Route.transaction do
        planning_route = planning_route_for!(operation_route)
        service.clear_route(planning_route)
        planning_route.save!
        operation_route.update_columns(last_sent_at: nil, last_sent_to: nil, updated_at: Time.current)
        present operation_route, with: V01::Entities::DeviceRouteLastSentAt
      end
    end

    def device_clear_routes(options = {})
      operation = find_operation!
      operation_routes = operation.operation_routes.planned.where.not(vehicle_id: nil).includes(:vehicle, :route)
      if options[:device_id]
        operation_routes = operation_routes.select { |oroute| oroute.vehicle&.devices&.[](options[:device_id]).present? }
      end
      operation_routes.each do |operation_route|
        Route.transaction do
          planning_route = planning_route_for!(operation_route)
          service.clear_route(planning_route)
          planning_route.save!
          operation_route.update_columns(last_sent_at: nil, last_sent_to: nil, updated_at: Time.current)
        end
      end
      present operation_routes, with: V01::Entities::DeviceRouteLastSentAt
    end

    # Orange
    def orange_sync_vehicles(customer)
      orange_vehicles = OrangeService.new(customer: customer).list_devices(params.slice(:user, :password))
      customer.vehicles.update_all devices: {orange_id: nil}
      orange_vehicles.each_with_index do |vehicle, index|
        next unless customer.vehicles[index]
        customer.vehicles[index].update! devices: {orange_id: vehicle[:id]}
      end
    end

    # Tekstat
    def teksat_authenticate(customer) # Must declare the ticket_id wich is needed for Teksat Api itself (up to 4 hours according to the documentation)
      if params[:check_only].to_i == 1 || !session[:teksat_ticket_id] || (Time.now - Time.at(session[:teksat_authenticated_at])) > 4.hours
        session[:teksat_ticket_id]        = TeksatService.new(customer: customer).authenticate teksat_credentials(customer)
        session[:teksat_authenticated_at] = Time.now.to_i
      end
    end

    def teksat_credentials(customer) # Return the formatted hash for Teksat authenticate method
      {
        url:                params[:url]                || customer.devices[:teksat][:url],
        teksat_customer_id: params[:teksat_customer_id] || customer.devices[:teksat][:teksat_customer_id],
        username:           params[:username]           || customer.devices[:teksat][:username],
        password:           params[:password]           || customer.devices[:teksat][:password]
      }
    end

    def teksat_sync_vehicles(customer, ticket_id)
      teksat_vehicles = TeksatService.new(customer: customer, ticket_id: ticket_id).list_devices
      customer.vehicles.update_all devices: {teksat_id: nil}
      teksat_vehicles.each_with_index do |vehicle, index|
        next unless customer.vehicles[index]
        customer.vehicles[index].update! devices: {teksat_id: vehicle[:id]}
      end
    end

    # TomTom
    def tomtom_sync_vehicles(customer)
      tomtom_vehicles = TomtomService.new(customer: customer).list_vehicles(params.slice(:account, :user, :password))
      tomtom_vehicles = tomtom_vehicles.select{ |item| !item[:objectUid].blank? }
      customer.vehicles.update_all devices: {tomtom_id: nil}
      tomtom_vehicles.each_with_index do |vehicle, index|
        next unless customer.vehicles[index]
        customer.vehicles[index].update! devices: {tomtom_id: vehicle[:objectUid]}, fuel_type: vehicle[:fuelType], color: vehicle[:color]
      end
    end
  end
end
