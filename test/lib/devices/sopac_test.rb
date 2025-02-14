require 'test_helper'

class SopacTest < ActionController::TestCase
  require Rails.root.join('test/lib/devices/sopac_base')
  include SopacBase

  setup do
    @customer = add_sopac_credentials customers(:customer_one)
    @service = Planner::Application.config.devices.sopac
  end

  test 'list devices' do
    skip 'Stub is not working properly'
    params = {
      login: @customer.devices[:sopac][:username],
      password: @customer.devices[:sopac][:password]
    }
    with_stubs [:list_devices] do
      assert @service.list_devices params
    end
  end

  test 'should get vehicle temperature' do
    params = {
      login: @customer.devices[:sopac][:username],
      password: @customer.devices[:sopac][:password],
      id: '2000352F'
    }
    with_stubs [:single_device] do
      assert @service.vehicles_temperature @customer
    end
  end

  test 'should raise on invalid param' do
    params = {
      login: '',
      password: ''
    }
    with_stubs [:auth] do
      assert_raise DeviceServiceError do
        @service.check_auth params
      end
    end
  end

end
