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
require 'test_helper'

class FleetTest < ActionController::TestCase

  require Rails.root.join('test/lib/devices/fleet_base')
  include FleetBase

  setup do
    @customer = customers(:customer_one)
    @customer.update(devices: { fleet: { enable: true, user: 'test', api_key: '123456' } }, enable_vehicle_position: true, enable_stop_status: true)
    @service = Planner::Application.config.devices.fleet
  end

  test 'should check authentication' do
    with_stubs [:auth] do
      params = {
        user: @customer.devices[:fleet][:user],
        api_key: @customer.devices[:fleet][:api_key]
      }
      assert @service.check_auth(params)
    end
  end

  test 'should check no authentication' do
    assert_raise do
      @service.check_auth({})
    end
  end

  test 'should get list of vehicles' do
    with_stubs [:get_users_url] do
      response = @service.list_devices(@customer)
      assert_kind_of Array, response
      assert response.all? { |v| v[:id] && v[:text] }
    end
  end

  test 'should get vehicles positions' do
    with_stubs [:get_vehicles_pos_url] do
      response = @service.get_vehicles_pos(@customer)
      assert_kind_of Array, response
      assert response.all? { |v| v[:fleet_vehicle_id] && v[:device_name] && v[:lat] && v[:lng] }
    end
  end

  test 'should update stop status' do
    set_route
    with_stubs [:fetch_stops] do
      planning = plannings(:planning_one)
      planning.routes.select(&:vehicle_usage_id).each { |route|
        route.last_sent_at = Time.now.utc
      }
      planning.fetch_stops_status
      planning.reload
      assert_equal ['Planned', 'Finished'], planning.routes.find{ |r| r.ref == 'route_one' }.stops.map(&:status).compact
    end
  end

  test 'should send route' do
    set_route
    with_stubs [:route_actions_url] do
      assert_nothing_raised do
        assert @service.send_route(@customer, routes(:route_one_one))
      end
    end
  end

  test 'should clear route' do
    set_route
    with_stubs [:route_actions_url] do
      assert_nothing_raised do
        @service.clear_route(@customer, routes(:route_one_one))
      end
    end
  end

  test 'should update routes status' do
    planning = plannings(:planning_one)
    set_route
    with_stubs [:fetch_stops] do
      planning.fetch_stops_status
      planning.save
      planning.reload

      assert_equal '2000-01-01 00:00:00 UTC', planning.routes.second.arrival_eta.utc.to_s
      assert_equal 'Finished', planning.routes.second.arrival_status
    end
  end

  test 'should clear routes status' do
    planning = plannings(:planning_one)
    with_stubs [:fetch_stops] do
      planning.routes.second.clear_eta_data
      planning.save
      planning.reload

      assert_nil planning.routes.second.arrival_eta
      assert_nil planning.routes.second.departure_eta
    end
  end

  test 'should get vId when ref contains characters' do
    ext_ref = 'mission-Test-tiret-v1757563-2018_08_01-159622'
    parts = @service.send(:decode_mission_id, ext_ref)
    assert_equal 'v1757563', parts[0]
  end

  test 'should get vId when no routes id has been specified' do
    ext_ref = 'mission-Test-tiret-v1757563-2018_08_01'
    parts = @service.send(:decode_mission_id, ext_ref)
    assert_equal 'v1757563', parts[0]
  end

  test 'should contains only departure and arrival when stops time are nil' do
    set_route
    fleet = Fleet.new
    route = routes(:route_one_one)
    route.stops.each{ |stop| stop.update(time: nil) }
    result = fleet.build_route_with_missions(route, @customer)

    assert_equal 2, result[:missions].count
  end

  test 'should return json on reporting if format is not csv' do
    set_route
    stub_request(:get, 'http://localhost:8084/api/0.1/reportings?format=json&from=2019-04-04&to=2019-05-01&with_actions=false')
        .to_return(status: 200, body: '[{"mission_action_final_label":"To do","mission_address":{"city":"bordeaux","country":"france","postalcode":"33000","street":"40 rue de canolle"},"mission_date":"2019-04-17T12:00:00.000+02:00","mission_duration":3600,"mission_external_ref":"mission-r15587-2019_04_17-1312","mission_id":"mission-a8c0f6ff9","mission_location":{"lat":44.828271,"lon":-0.602265},"mission_name":"jean roger Pomme"}]')

    params = {format: 'json', from: '2019-04-04', to: '2019-05-01', with_actions: false}
    result = @service.reporting('demo', 'en', params)

    assert_kind_of Hash, result.first
  end
end
