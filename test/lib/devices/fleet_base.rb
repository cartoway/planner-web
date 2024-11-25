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
module FleetBase
  def set_route
    planning = plannings(:planning_one)
    planning.update!(date: 10.days.from_now)
    planning.routes.select(&:vehicle_usage_id).each do |route|
      route.update!(end: (route.start || 0) + 1.hour)
    end

    @route = routes(:route_one_one)
    @route.update!(hidden: false)
    @vehicle = @route.vehicle_usage.vehicle
    @vehicle.update!(devices: { fleet_user: 'driver1' })
    @customer.reload # TODO: Check if necessary
  end

  def with_stubs(names, &block)
    begin
      stubs = []
      names.each do |name|
        case name
          when :auth
            url = FleetService.new(customer: @customer).service.send(:get_user_url, @customer.devices[:fleet][:user])
            expected_response = {
              user: @customer.devices[:fleet][:user]
            }.to_json
            stubs << stub_request(:get, url).to_return(status: 200, body: expected_response)
          when :get_users_url
            url = FleetService.new(customer: @customer).service.send(:get_users_url, with_vehicle: true)
            expected_response = {
              users: [
                {
                  sync_user: 'driver1',
                  email: 'driver1@example.com',
                  color: '#000'
                },
                {
                  sync_user: 'driver2',
                  email: 'driver2@example.com'
                }
              ]
            }.to_json
            stubs << stub_request(:get, url).to_return(status: 200, body: expected_response)
          when :get_vehicles_pos_url
            url = FleetService.new(customer: @customer).service.send(:get_vehicles_pos_url)
            expected_response = {
              user_current_locations: [
                {
                  sync_user: 'driver1',
                  name: 'driver1',
                  location_detail: {
                    lat: 40.2,
                    lon: 4.5,
                    time: '20.11.2017',
                    speed: 30,
                  }
                }
              ]
            }.to_json
            stubs << stub_request(:get, url).to_return(status: 200, body: expected_response)
          when :fetch_stops
            Time.zone = 'Hawaii'
            planning = plannings(:planning_one)
            planning_date = DateTime.now.strftime('%Y_%m_%d')
            reference_ids = planning.routes.select(&:vehicle_usage?).collect(&:stops).flatten.collect { |stop| (stop.is_a?(StopVisit) ? "mission-v#{stop.visit_id}-#{planning_date}" : "mission-r#{stop.id}-#{planning_date}") }.uniq
            fs = FleetService.new(customer: @customer).service

            # Urls used to contact the fleet-api routes with missions
            # Pattern: "{base}/api/0.1/routes/{route_id}?user_id=[a-z0-9]&with_missions=boolean"
            urls = planning.routes.select(&:vehicle_usage?).collect { |route|
              fs.send(:get_route_url, route.vehicle_usage.vehicle.devices[:fleet_user], fs.send(:generate_route_id, route, p_time(route, route.start)), true)
            }

            expected_response = {
              route: {
                missions: [
                  {
                    external_ref: reference_ids[2],
                    status_type_reference: 'mission_to_do',
                    status_type_label: 'To do',
                    status_type_color: '#fff'
                  },
                  {
                    external_ref: reference_ids[3],
                    status_type_reference: 'mission_completed',
                    status_type_label: 'Completed',
                    status_type_color: '#000'
                  },
                  {
                    mission_type: 'arrival',
                    external_ref: "arrival-#{planning.routes.second.vehicle_usage.default_store_start.id}-#{planning_date}-#{planning.routes.second.id}",
                    status_type_reference: 'mission_completed',
                    status_type_label: 'To do',
                    status_type_color: '#fff',
                    eta: '2000-01-01 00:00:00.00 UTC'
                  }
                ]
              }
            }.to_json
            urls.each { |url| stubs << stub_request(:get, url).to_return(status: 200, body: expected_response) }
          when :set_missions_url
            url = FleetService.new(customer: @customer).service.send(:set_missions_url, 'driver1')
            expected_response = {
              missions: [
              ]
            }.to_json
            stubs << stub_request(:post, url).to_return(status: 200, body: expected_response)
          when :delete_missions_by_date_url
            planning = plannings(:planning_one)
            planning_date = planning.date ? planning.date.beginning_of_day.to_time : Time.zone.now.beginning_of_day
            planning.routes.select(&:vehicle_usage_id).each do |route|
              start_date = (planning_date + (route.start || 0)).strftime('%Y-%m-%d')
              end_date = (planning_date + (route.end || 0) + 2.day).strftime('%Y-%m-%d')

              url = FleetService.new(customer: @customer).service.send(:delete_missions_by_date_url, 'driver1', start_date, end_date)
              stubs << stub_request(:delete, url).to_return(status: 204, body: nil)
            end
          when :route_actions_url
            Time.zone = 'Hawaii'
            fs = FleetService.new(customer: @customer)
            ext_ref = "route-#{@route.id}-#{fs.p_time(@route, @route.start).in_time_zone.strftime('%Y_%m_%d')}"

            url = fs.service.send(:get_route_url, @vehicle.devices[:fleet_user], ext_ref)
            post = fs.service.send(:post_routes_url, 'driver1')
            put =  fs.service.send(:put_routes_url, 'driver1', true, ext_ref)

            stubs << stub_request(:get, url).to_return(status: 404, body: nil, headers: {})
            stubs << stub_request(:post, post).to_return(status: 200, body: nil, headers: {})
            stubs << stub_request(:any, put).to_return(status: 200, body: nil, headers: {})
          when :create_or_update_drivers
            url = FleetService.new(customer: @customer).service.send(:create_or_update_drivers)
            stubs << stub_request(:get, url).to_return(status: 200, body: [{:email=>"toto@toto.toto", :updated=>true}])
        end
      end
      yield
    ensure
      stubs.each do |name|
        remove_request_stub name
      end
    end
  end
end
