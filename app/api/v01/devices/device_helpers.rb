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
    def device_send_routes(options = {})
      planning = @current_customer.plannings.find params[:planning_id]
      routes = planning.routes.select(&:vehicle_usage_id)
      routes = routes.select{ |route| route.vehicle_usage.vehicle.devices[options[:device_id]] } if options[:device_id]
      routes.select{ |r| r.stops.only_active_stop_visits.select{ |s| s.position? }.size > 0 }.each{ |route|
        Route.transaction do
          service.send_route(route, options)
          route.save!
        end
      }
      present routes, with: V01::Entities::DeviceRouteLastSentAt
    end

    def device_clear_route(_options = {})
      Route.transaction do
        route = Route.for_customer_id(@current_customer.id).find params[:route_id]
        service.clear_route(route)
        route.save!
        present route, with: V01::Entities::DeviceRouteLastSentAt
      end
    end

    def device_clear_routes(options = {})
      planning = @current_customer.plannings.find params[:planning_id]
      routes = planning.routes.select(&:vehicle_usage_id)
      routes = routes.select{ |route| route.vehicle_usage.vehicle.devices[options[:device_id]] } if options[:device_id]
      routes.each{ |route|
        Route.transaction do
          service.clear_route(route)
          route.save!
        end
      }
      present routes, with: V01::Entities::DeviceRouteLastSentAt
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

    # Fleet
    def fleet_sync_vehicles(customer)
      fleet_vehicles = FleetService.new(customer: customer).list_vehicles(params.slice(:user))
      customer.vehicles.update_all(devices: {fleet_user: nil})
      fleet_vehicles.each_with_index do |vehicle, index|
        next unless customer.vehicles[index]
        customer.vehicles[index].update!(devices: {fleet_user: vehicle[:id]}, color: vehicle[:color])
      end
    end
  end
end
