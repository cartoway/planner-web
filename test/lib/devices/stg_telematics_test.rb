require 'test_helper'

class StgTelematicsTest < ActionController::TestCase

  require Rails.root.join("test/lib/devices/stg_telematics_base")
  include StgTelematicsBase

  setup do
    @customer = add_stg_telematics_credentials customers(:customer_one)
    @service = Planner::Application.config.devices.stg_telematics
  end

  test 'authenticate' do
    with_stubs [:auth] do
      assert @service.authenticate @customer, { url: @customer.devices[:stg_telematics][:url], company_names: @customer.devices[:stg_telematics][:company_names], username: @customer.devices[:stg_telematics][:username], password: @customer.devices[:stg_telematics][:password] }
    end
  end

  test 'list devices' do
    with_stubs [:auth, :get_vehicles] do
      assert @service.list_devices @customer
    end
  end

  test 'get vehicles positions' do
    with_stubs [:auth, :vehicles_pos] do
      assert @service.get_vehicles_pos @customer
    end
  end

end
