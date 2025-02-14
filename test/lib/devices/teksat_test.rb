require 'test_helper'

class TeksatTest < ActionController::TestCase

  require Rails.root.join("test/lib/devices/teksat_base")
  include TeksatBase

  setup do
    @customer = add_teksat_credentials customers(:customer_one)
    @service = Planner::Application.config.devices.teksat
  end

  test 'authenticate' do
    with_stubs [:auth] do
      assert @service.authenticate @customer, { url: @customer.devices[:teksat][:url], teksat_customer_id: @customer.devices[:teksat][:teksat_customer_id], username: @customer.devices[:teksat][:username], password: @customer.devices[:teksat][:password] }
    end
  end

  test 'list devices' do
    with_stubs [:auth, :get_vehicles] do
      assert @service.list_devices @customer
    end
  end

  test 'send route' do
    with_stubs [:auth, :send_route] do
      set_route
      assert_nothing_raised do
        @service.send_route @customer, @route
      end
    end
  end

  test 'clear route' do
    with_stubs [:auth, :clear_route] do
      set_route
      assert_nothing_raised do
        @service.clear_route @customer, @route
      end
    end
  end

  test 'get vehicles positions' do
    with_stubs [:auth, :vehicles_pos] do
      assert @service.get_vehicles_pos @customer
    end
  end

end
