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

class V01::Devices::FleetTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  require Rails.root.join('test/lib/devices/api_base')
  include ApiBase

  require Rails.root.join('test/lib/devices/fleet_base')
  include FleetBase

  setup do
    @customer = customers(:customer_one)
    @customer.update(devices: { fleet: { enable: true, user: 'driver1', api_key: '123456' } }, enable_vehicle_position: true, enable_stop_status: true)
    set_route
  end

  def planning_api(part = nil, param = {})
    part = part ? '/' + part.to_s : ''
    "/api/0.1/plannings#{part}.json?api_key=testkey1&" + param.collect { |k, v| "#{k}=" + URI::DEFAULT_PARSER.escape(v.to_s) }.join('&')
  end

  test 'authenticate' do
    with_stubs [:auth] do
      get api("devices/fleet/auth/#{@customer.id}", params_for(:fleet, @customer))
      assert_equal 204, last_response.status
    end
  end

  test 'should send route' do
    with_stubs [:route_actions_url] do
      route = routes(:route_one_one)
      post api('devices/fleet/send', { customer_id: @customer.id, route_id: route.id })
      assert_equal 201, last_response.status, last_response.body
      route.reload
      assert route.reload.last_sent_at
      assert_equal({ 'id' => route.id, 'last_sent_to' => 'Mapo. Live', 'last_sent_at' => route.last_sent_at.iso8601(3), 'last_sent_at_formatted' => I18n.l(route.last_sent_at) }, JSON.parse(last_response.body))
    end
  end

  test 'list devices' do
    with_stubs [:get_users_url] do
      get api('devices/fleet/devices', { customer_id: @customer.id })
      assert_equal 200, last_response.status
      assert JSON.parse(last_response.body).all? { |v| v['id'] && v['text'] }
    end
  end

  test 'should return vehicle positions' do
    with_stubs [:vehicle_pos_url] do
      get api('vehicles/current_position'), { ids: @customer.vehicle_ids }
      assert_equal 200, last_response.status, last_response.body
      response = JSON.parse(last_response.body)
      assert_equal 1, response.size
      assert response.all? { |v| v['lat'] && v['lng'] }
    end
  end

  test 'should send multiple routes' do
    with_stubs [:route_actions_url] do
      planning = plannings(:planning_one)
      post api('devices/fleet/send_multiple', { customer_id: @customer.id, planning_id: planning.id })
      assert_equal 201, last_response.status, last_response.body
      routes = planning.routes.select(&:vehicle_usage_id)
      routes.each(&:reload)
      routes.each { |route|
        assert_equal([{ 'id' => route.id, 'last_sent_to' => 'Mapo. Live', 'last_sent_at' => route.last_sent_at.iso8601(3), 'last_sent_at_formatted' => I18n.l(route.last_sent_at) }], JSON.parse(last_response.body)) if route.ref == 'route_one'
      }
    end
  end

  test 'should clear' do
    with_stubs [:route_actions_url] do
      route = routes(:route_one_one)
      delete api('devices/fleet/clear', { customer_id: @customer.id, route_id: route.id })
      assert_equal 200, last_response.status
      route.reload
      assert !route.last_sent_at
      assert_equal({ 'id' => route.id, 'last_sent_to' => nil, 'last_sent_at' => nil, 'last_sent_at_formatted' => nil }, JSON.parse(last_response.body))
    end
  end

  test 'should clear multiple' do
    with_stubs [:route_actions_url] do
      planning = plannings(:planning_one)
      route = routes(:route_one_one)
      service = FleetService.new(customer: @customer).service
      ref = service.send(:generate_route_id, route, service.p_time(route, route.start))
      route.update(last_sent_at: Time.now, last_sent_to: 'Mapo.Live')

      delete api('devices/fleet/clear_multiple', customer_id: @customer.id), external_refs: [{fleet_user: 'fake_user@example.com', external_ref: ref}]
      assert_equal 200, last_response.status

      assert_equal([route.id, nil, nil, nil],
        JSON.parse(last_response.body).flat_map{ |rt|
          [rt['id'], rt['last_sent_to'], rt['last_sent_at'], rt['last_sent_at_formatted']]
        })

      routes = planning.routes.select(&:vehicle_usage_id)
      routes.each(&:reload)
      routes.each { |rt| assert !rt.last_sent_at }
    end
  end

  test 'should fetch routes' do
    Time.use_zone(users(:user_one).time_zone) do
      less12_hours = (Time.zone.now - 12.hour).to_date.to_s
      vehicle_1_name = vehicles(:vehicle_one).name
      stub_request(:get, %r{.*/api/0.1/routes\?from=#{less12_hours}.*$})
        .to_return(status: 200, body: "{
          \"routes\": [
            {
              \"id\": \"route-kzLpSZb5wY\",
              \"external_ref\": \"route-146067-2018_09_06\",
              \"name\": \"#{vehicle_1_name}\",
              \"user_id\": \"user-fIxc7jcZYs\",
              \"sync_user\": \"5ffbb992f9c44a4e7a50897f785c5f63d38e587130f7cf86a07359d609dc50dd\",
              \"date\": \"#{less12_hours}T08:00:00.000+02:00\"
            }
          ]
        }")

      get api('devices/fleet/fetch_routes', planning_id: plannings(:planning_one).id)
      assert JSON.parse(last_response.body).first['routes_by_fleet_user'][0]['fleet_user'].is_a? String
    end
  end

  test 'sending_route_should_contain_quantities' do
    @customer.update(enable_orders: false)
    route = routes(:route_one_one)

    [{method: :put, status: 200}, {method: :post, status: 404}].each do |obj|
      stub_request(:get, %r{.*api/0.1/routes.*}).to_return(status: obj[:status])
      stub_request(obj[:method], %r{.*api/0.1/routes.*})
        .with(body: /"quantities":/)
        .to_return(status: 200)

      post api('devices/fleet/send', customer_id: @customer.id, route_id: route.id)
      assert_equal 201, last_response.status, last_response.body
    end
  end

  test 'fetch stops and update quantities' do
    customers(:customer_one).update(job_optimizer_id: nil)

    with_stubs [:fetch_stops] do
      @customer.update_attribute(:enable_stop_status, true)
      planning = plannings(:planning_one)

      patch planning_api("#{planning.id}/update_stops_status", details: true)
      assert_equal 200, last_response.status
      assert_kind_of Array, JSON.parse(last_response.body)
      planning.reload

      route = planning.routes.select { |route| route.vehicle_usage? && route.ref == 'route_one' }.first
      status = route.stops.select { |s| s.active? && (s.status == 'Planned' || s.status == 'Finished') }

      assert_equal ['Planned', 'Finished'], status.collect(&:status)
    end
  end

  test 'can create or update vehicles only if user is authorized fleet administration' do
    @customer.reseller.update_attribute(:authorized_fleet_administration, true)

    with_stubs [:create_or_update_vehicle] do
      stub_request(:put, %r{^.*/api/0.1/users/.*$})

      patch api('devices/fleet/create_or_update_drivers', { customer_id: @customer.id })
      assert JSON.parse(last_response.body).first['updated']
    end
  end
end
