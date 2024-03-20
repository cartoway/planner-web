require 'test_helper'

class V01::Devices::StgTelematicsTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  require Rails.root.join('test/lib/devices/api_base')
  include ApiBase

  require Rails.root.join('test/lib/devices/stg_telematics_base')
  include StgTelematicsBase

  setup do
    @customer = add_stg_telematics_credentials customers(:customer_one)
  end

  test 'authenticate' do
    with_stubs [:auth] do
      get api("devices/stg_telematics/auth/#{@customer.id}", params_for(:stg_telematics, @customer))
      assert_equal 204, last_response.status, last_response.body
    end
  end

  test 'list devices' do
    with_stubs [:auth, :get_vehicles] do
      get api("devices/stg_telematics/devices")
      assert_equal 200, last_response.status, last_response.body
      assert_equal [
        {id: '12345-V-6', text: '12345-V-6 Truck'},
        {id: '23456-W-7', text: '23456-W-7 Truck'}
      ], JSON.parse(last_response.body, symbolize_names: true)
    end
  end

  test 'vehicle positions' do
    with_stubs [:auth, :vehicles_pos] do
      set_route
      get api('vehicles/current_position'), ids: @customer.vehicle_ids
      assert_equal 200, last_response.status
      assert_equal  [{
        vehicle_id: @vehicle.id,
        device_name: '12345-V-6',
        lat: 43.34022,
        lng: -0.45711,
        direction: nil,
        speed: "37",
        time: "19 Mar 2024 09:30:10+00:00",
        time_formatted: "18 mars 2024 23:30:10"
      }], JSON.parse(last_response.body, symbolize_names: true)
    end
  end
end
