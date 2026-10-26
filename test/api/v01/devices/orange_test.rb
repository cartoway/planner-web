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
require 'test_helper'

class V01::Devices::OrangeTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  require Rails.root.join("test/lib/devices/api_base")
  include ApiBase

  require Rails.root.join("test/lib/devices/orange_base")
  include OrangeBase

  setup do
    @customer = add_orange_credentials customers(:customer_one)
  end

  test 'authenticate' do
    with_stubs [:auth] do
      get api("devices/orange/auth/#{@customer.id}", params_for(:orange, @customer))
      assert_equal 204, last_response.status
    end
  end

  test 'list devices' do
    # ============================
    #           Unused
    # ============================
    # with_stubs [:get_vehicles] do
    #   get api("devices/orange/devices", { customer_id: @customer.id })
    #   assert_equal 200, last_response.status
    #   assert_equal [{"id"=>"325000749", "text"=>"Eric 590 - DB-116-CL"}], JSON.parse(last_response.body)
    # end
  end

  test 'vehicle positions' do
    with_stubs [:vehicles_pos] do
      set_route
      get api("vehicles/current_position"), { ids: @customer.vehicle_ids }
      assert_equal 200, last_response.status
      assert_equal [{
        "vehicle_id"=>@vehicle.id,
        "device_name"=>"Eric 590",
        "lat"=>"44.813109",
        "lng"=>"-0.562738",
        "direction"=>nil,
        "speed"=>"2",
        "time"=>"2016-02-16 11:19:35+00:00",
        "time_formatted"=>"16 février 2016 01:19:35"}
      ], JSON.parse(last_response.body), last_response.body
    end
  end

  test 'send' do
    with_stubs [:send] do
      set_route
      _operation, operation_route = publish_operation_for!(@route)
      post api("devices/orange/send", { customer_id: @customer.id, operation_route_id: operation_route.id })
      assert_equal 201, last_response.status
      operation_route.reload
      assert operation_route.last_sent_at
      assert_equal last_sent_payload(operation_route), JSON.parse(last_response.body)
    end
  end

  test 'send multiple' do
    with_stubs [:send] do
      set_route
      operation, _operation_route = publish_operation_for!(@route)
      post api("devices/orange/send_multiple", { customer_id: @customer.id, operation_id: operation.id })
      assert_equal 201, last_response.status
      routes = operation.operation_routes.select { |oroute| oroute.vehicle&.devices&.[](:orange_id) }
      routes.each(&:reload)
      routes.each { |oroute| assert oroute.last_sent_at }
      assert_equal(routes.map { |oroute| last_sent_payload(oroute) }, JSON.parse(last_response.body))
    end
  end

  test 'clear' do
    with_stubs [:send] do
      set_route
      _operation, operation_route = publish_operation_for!(@route)
      operation_route.update_columns(last_sent_at: Time.current, last_sent_to: 'Orange')
      delete api("devices/orange/clear", { customer_id: @customer.id, operation_route_id: operation_route.id })
      assert_equal 200, last_response.status
      operation_route.reload
      assert_nil operation_route.last_sent_at
      assert_equal last_sent_payload(operation_route), JSON.parse(last_response.body)
    end
  end

  test 'clear multiple' do
    with_stubs [:send] do
      set_route
      operation, _operation_route = publish_operation_for!(@route)
      routes = operation.operation_routes.select { |oroute| oroute.vehicle&.devices&.[](:orange_id) }
      routes.each { |oroute| oroute.update_columns(last_sent_at: Time.current, last_sent_to: 'Orange') }
      delete api("devices/orange/clear_multiple", { customer_id: @customer.id, operation_id: operation.id })
      assert_equal 200, last_response.status
      routes.each(&:reload)
      routes.each { |oroute| assert_nil oroute.last_sent_at }
      assert_equal(routes.map { |oroute| last_sent_payload(oroute) }, JSON.parse(last_response.body))
    end
  end

  test 'sync' do
    # ============================
    #           Unused
    # ============================
    # with_stubs [:get_vehicles] do
    #   set_route

    #   # Customer Already Have Devices
    #   @customer.vehicles.update_all devices: {orange_id: "orange_id"}

    #   # Reset Vehicle
    #   @customer.vehicles.reload ; @vehicle.reload
    #   assert_equal "orange_id", @vehicle.devices[:orange_id]

    #   # Send Request.. Send Credentials As Parameters
    #   post api("devices/orange/sync")
    #   assert_equal 204, last_response.status, last_response.body

    #   # Vehicle Should Now Have All Values
    #   @customer.vehicles.reload ; @vehicle.reload
    #   assert_equal "325000749", @vehicle.devices[:orange_id]
    # end
  end
end
